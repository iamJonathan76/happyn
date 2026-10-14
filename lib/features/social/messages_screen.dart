import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/messages_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/l10n/app_localizations.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final conversations = ref.watch(directConversationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.messages, style: AppText.h3),
      ),
      body: conversations.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => Center(
          child: Text(l.messagesLoadFailed,
              style: AppText.bodySm.copyWith(color: AppColors.textLow)),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.forum_outlined,
                          size: 42, color: AppColors.textLow),
                      const SizedBox(height: 12),
                      Text(l.noMessages,
                          textAlign: TextAlign.center,
                          style: AppText.bodySm.copyWith(
                              color: AppColors.textLow)),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async =>
                    ref.invalidate(directConversationsProvider),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 76,
                    color: Colors.white.withOpacity(0.06),
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final other =
                        item['other_user'] as Map<String, dynamic>;
                    final name = (other['full_name'] as String?) ?? l.user;
                    final avatar = (other['avatar_url'] as String?) ?? '';
                    final lastMessage =
                        item['last_message'] as Map<String, dynamic>?;
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      leading: _MessageAvatar(url: avatar, name: name),
                      title: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        (lastMessage?['body'] as String?) ?? l.startConversation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textLow),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            conversationId: item['id'] as String,
                            otherUserId: item['other_user_id'] as String,
                            otherUserName: name,
                            otherUserAvatar: avatar,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class DirectChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const DirectChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await sendDirectMessage(widget.conversationId, body);
      _controller.clear();
      ref.invalidate(directConversationsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).messageSendFailed),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final messages = ref.watch(directMessagesProvider(widget.conversationId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            _MessageAvatar(
                url: widget.otherUserAvatar ?? '', name: widget.otherUserName),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.otherUserName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h3),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, _) => Center(
                child: Text(l.messagesLoadFailed,
                    style: AppText.bodySm.copyWith(color: AppColors.textLow)),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(l.startConversation,
                          style: AppText.bodySm.copyWith(
                              color: AppColors.textLow)),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final message = items[items.length - index - 1];
                        final isMine = message['sender_id'] == userId;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.78),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? AppColors.primary
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(message['body'] as String,
                                style: AppText.bodySm
                                    .copyWith(color: Colors.white)),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: l.writeMessage,
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: l.sendMessage,
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  final String url;
  final String name;

  const _MessageAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: 23,
      backgroundColor: AppColors.primary.withOpacity(0.25),
      foregroundImage: url.isEmpty ? null : CachedNetworkImageProvider(url),
      child: Text(initial,
          style: AppText.bodySm.copyWith(
              color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}
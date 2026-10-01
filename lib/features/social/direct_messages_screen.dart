import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/direct_messages_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/l10n/app_localizations.dart';

class DirectMessagesScreen extends ConsumerWidget {
  const DirectMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final conversations = ref.watch(directConversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.messages, style: AppText.h3),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          ref.invalidate(directConversationsProvider);
          await ref.read(directConversationsProvider.future);
        },
        child: conversations.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, _) => _empty(context, l.messagesLoadFailed),
          data: (items) => items.isEmpty
              ? _empty(context, l.noMessagesYet)
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final name = (item['other_name'] as String?)?.trim() ?? '';
                    final username = item['other_username'] as String? ?? '';
                    final title = name.isNotEmpty
                        ? name
                        : (username.isNotEmpty ? '@$username' : l.userLabel);
                    final avatar = item['other_avatar'] as String? ?? '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: _Avatar(url: avatar, name: title),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        item['last_message'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: AppColors.textLow,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppDates.messageDateTime(
                              context,
                              item['last_message_at'] as String?,
                            ),
                            style: AppText.micro.copyWith(
                              color: AppColors.textLow,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right, color: AppColors.textLow),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DirectMessageThreadScreen(
                              conversationId: item['conversation_id'] as String,
                              recipientName: title,
                              recipientAvatar: avatar,
                            ),
                          ),
                        );
                        ref.invalidate(directConversationsProvider);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, String text) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 140),
    children: [
      Icon(Icons.forum_outlined, size: 44, color: AppColors.textFaint),
      const SizedBox(height: 12),
      Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.bodySm.copyWith(color: AppColors.textLow),
      ),
    ],
  );
}

class DirectMessageThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String recipientName;
  final String recipientAvatar;

  const DirectMessageThreadScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    required this.recipientAvatar,
  });

  @override
  ConsumerState<DirectMessageThreadScreen> createState() =>
      _DirectMessageThreadScreenState();
}

class _DirectMessageThreadScreenState
    extends ConsumerState<DirectMessageThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).messageSendFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final messages = ref.watch(directMessagesProvider(widget.conversationId));
    ref.listen(directMessagesProvider(widget.conversationId), (_, next) {
      if (!next.hasValue) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    });
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            _Avatar(
              url: widget.recipientAvatar,
              name: widget.recipientName,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.h4.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, _) => Center(
                child: Text(
                  l.messagesLoadFailed,
                  style: AppText.bodySm.copyWith(color: AppColors.textLow),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      l.startConversation,
                      style: AppText.bodySm.copyWith(color: AppColors.textLow),
                    ),
                  );
                }
                if (!_didInitialScroll) {
                  _didInitialScroll = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
                    final isMine = message['sender_id'] == currentUserId;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMine ? AppColors.primaryGradient : null,
                          color: isMine ? null : AppColors.card,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMine ? 16 : 4),
                            bottomRight: Radius.circular(isMine ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message['body'] as String? ?? '',
                              style: AppText.bodySm.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppDates.messageDateTime(
                                context,
                                message['created_at'] as String?,
                              ),
                              style: AppText.micro.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                      decoration: InputDecoration(
                        hintText: l.messageHint,
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    tooltip: l.sendMessage,
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

class _Avatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;

  const _Avatar({required this.url, required this.name, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.primary.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: AppText.bodySm.copyWith(color: AppColors.lavenderLight),
      ),
    );
    return ClipOval(
      child: url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

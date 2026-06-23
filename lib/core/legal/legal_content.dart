/// Contenu légal de HAPPYN, transcrit du « Legal & Policy Handbook v1.0 ».
/// Source unique de vérité affichée par les pages Legal du Settings.
library;

class LegalSection {
  final String? heading;
  final List<String> paragraphs;
  final List<String> bullets;
  const LegalSection({
    this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

class LegalDoc {
  final String title;
  final List<LegalSection> sections;
  const LegalDoc({required this.title, required this.sections});
}

const String kLegalVersion = 'Version 1.0 · June 2026';

const Map<String, LegalDoc> kLegalDocs = {
  'terms': LegalDoc(
    title: 'Terms of Service',
    sections: [
      LegalSection(paragraphs: [
        'Welcome to HAPPYN. By accessing or using HAPPYN, you agree to these Terms.',
      ]),
      LegalSection(
        heading: '1. Eligibility',
        paragraphs: ['Users must be at least 13 years old.'],
      ),
      LegalSection(
        heading: '2. Accounts',
        paragraphs: [
          'Users are responsible for maintaining the security of their account credentials.',
        ],
      ),
      LegalSection(
        heading: '3. Platform Purpose',
        paragraphs: [
          'HAPPYN enables users to discover, create, promote, and attend events.',
        ],
      ),
      LegalSection(
        heading: '4. Prohibited Conduct',
        paragraphs: [
          'Fraudulent events, harassment, impersonation, illegal activity, spam, and abuse are prohibited.',
        ],
      ),
      LegalSection(
        heading: '5. Event Organizers',
        paragraphs: [
          'Organizers are responsible for the accuracy, legality, safety, and execution of their events.',
        ],
      ),
      LegalSection(
        heading: '6. Suspension and Termination',
        paragraphs: [
          'HAPPYN may suspend or terminate accounts that violate these Terms.',
        ],
      ),
      LegalSection(
        heading: '7. Limitation of Liability',
        paragraphs: [
          'HAPPYN is not responsible for losses, injuries, disputes, or damages resulting from attendance at events.',
        ],
      ),
      LegalSection(
        heading: '8. Modifications',
        paragraphs: ['HAPPYN may update these Terms at any time.'],
      ),
    ],
  ),
  'privacy': LegalDoc(
    title: 'Privacy Policy',
    sections: [
      LegalSection(paragraphs: ['HAPPYN respects user privacy.']),
      LegalSection(
        heading: 'Information collected may include:',
        bullets: [
          'Name',
          'Email address',
          'Profile photo',
          'City and location preferences',
          'Event activity and attendance history',
          'Device and usage information',
        ],
      ),
      LegalSection(
        heading: 'We use this information to:',
        bullets: [
          'Provide recommendations',
          'Improve the platform',
          'Process registrations',
          'Send important notifications',
        ],
      ),
      LegalSection(paragraphs: [
        'We do not sell personal information.',
        'Users may request access, correction, or deletion of their data.',
      ]),
    ],
  ),
  'community': LegalDoc(
    title: 'Community Guidelines',
    sections: [
      LegalSection(paragraphs: [
        'Our goal is to maintain a safe and welcoming community.',
      ]),
      LegalSection(
        heading: 'Users must:',
        bullets: [
          'Respect others',
          'Provide accurate information',
          'Follow applicable laws',
        ],
      ),
      LegalSection(
        heading: 'Users may not:',
        bullets: [
          'Harass or threaten others',
          'Post hateful content',
          'Create fake accounts',
          'Promote illegal activity',
          'Mislead attendees',
        ],
      ),
      LegalSection(paragraphs: [
        'Violations may result in warnings, suspensions, or permanent bans.',
      ]),
    ],
  ),
  'cookie': LegalDoc(
    title: 'Cookie Policy',
    sections: [
      LegalSection(
        heading: 'HAPPYN uses cookies and similar technologies to:',
        bullets: [
          'Keep users signed in',
          'Remember preferences',
          'Improve performance',
          'Analyze platform usage',
        ],
      ),
      LegalSection(paragraphs: [
        'Users may disable cookies through browser settings, although some features may not function properly.',
      ]),
    ],
  ),
  'copyright': LegalDoc(
    title: 'Copyright Policy',
    sections: [
      LegalSection(paragraphs: [
        'All HAPPYN trademarks, branding, software, designs, and original content are protected by intellectual property laws.',
        'Users retain ownership of content they upload but grant HAPPYN a non-exclusive license to display and distribute that content on the platform.',
        'Copyright complaints may be submitted to HAPPYN support.',
      ]),
    ],
  ),
  'refund': LegalDoc(
    title: 'Refund Policy',
    sections: [
      LegalSection(paragraphs: [
        'Refund policies are determined by event organizers.',
        'If an event is cancelled, attendees may be eligible for refunds according to the organizer’s policy and applicable law.',
        'Platform service fees may be non-refundable unless otherwise required.',
      ]),
    ],
  ),
  'safety': LegalDoc(
    title: 'Safety Policy',
    sections: [
      LegalSection(paragraphs: [
        'Users should exercise good judgment when attending events.',
      ]),
      LegalSection(
        heading: 'HAPPYN encourages users to:',
        bullets: [
          'Meet in safe environments',
          'Follow venue rules',
          'Report suspicious activity',
        ],
      ),
      LegalSection(paragraphs: [
        'Emergency situations should be reported directly to local authorities.',
      ]),
    ],
  ),
  'organizer': LegalDoc(
    title: 'Organizer Standards',
    sections: [
      LegalSection(
        heading: 'Organizers must:',
        bullets: [
          'Provide accurate event information',
          'Honor ticket commitments',
          'Comply with local laws',
          'Respect attendee privacy',
        ],
      ),
      LegalSection(paragraphs: [
        'Repeated violations may result in organizer account removal.',
      ]),
    ],
  ),
};

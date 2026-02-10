/// Mock email data for demo mode
///
/// Provides 50+ sample emails with variety for UI testing and demonstration
/// without requiring live email account access.
library;

import '../models/email_message.dart';

/// Generate sample emails for demo mode
class MockEmailData {
  /// Generate comprehensive set of 50+ sample emails
  static List<EmailMessage> generateSampleEmails() {
    final now = DateTime.now();
    final emails = <EmailMessage>[];

    // ========================================
    // CATEGORY 1: Obvious Spam (15 emails)
    // ========================================
    
    // Lottery/Prize scams
    emails.add(EmailMessage(
      id: 'demo-001',
      from: 'winner@lottery-scam.com',
      subject: 'YOU WON \$1,000,000!!! CLAIM NOW!!!',
      body: 'Congratulations! You have been selected as a winner. Click here to claim your prize.',
      headers: {'From': 'winner@lottery-scam.com'},
      receivedDate: now.subtract(const Duration(hours: 1)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-002',
      from: 'prizes@mega-jackpot.net',
      subject: 'URGENT: \$500,000 Prize Notification',
      body: 'You must respond within 24 hours to claim your mega jackpot prize.',
      headers: {'From': 'prizes@mega-jackpot.net'},
      receivedDate: now.subtract(const Duration(hours: 2)),
      folderName: 'INBOX',
    ));

    // Nigerian prince / inheritance scams
    emails.add(EmailMessage(
      id: 'demo-003',
      from: 'prince.nigeria@yahoo.com',
      subject: 'Urgent Business Proposal - \$25 Million',
      body: 'Dear Sir/Madam, I am Prince Okonkwo and I need your help transferring \$25 million.',
      headers: {'From': 'prince.nigeria@yahoo.com'},
      receivedDate: now.subtract(const Duration(hours: 3)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-004',
      from: 'lawyer@inheritance-claims.org',
      subject: 'You have inherited \$10M from distant relative',
      body: 'We represent the estate of your late relative. Contact us immediately.',
      headers: {'From': 'lawyer@inheritance-claims.org'},
      receivedDate: now.subtract(const Duration(hours: 4)),
      folderName: 'INBOX',
    ));

    // Pharmaceutical spam
    emails.add(EmailMessage(
      id: 'demo-005',
      from: 'sales@cheap-meds-online.biz',
      subject: 'V1AGRA & C1AL1S - 70% OFF TODAY',
      body: 'Order now and save big on all your medication needs. No prescription required.',
      headers: {'From': 'sales@cheap-meds-online.biz'},
      receivedDate: now.subtract(const Duration(hours: 5)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-006',
      from: 'pharmacy@discount-pills.info',
      subject: 'Lowest Prices on Prescription Meds!!!',
      body: 'Get all your medications at unbeatable prices. Free shipping worldwide.',
      headers: {'From': 'pharmacy@discount-pills.info'},
      receivedDate: now.subtract(const Duration(hours: 6)),
      folderName: 'INBOX',
    ));

    // Casino / gambling spam
    emails.add(EmailMessage(
      id: 'demo-007',
      from: 'promo@online-casino-wins.com',
      subject: '\$1000 Free Casino Bonus - Play Now',
      body: 'Start playing today with \$1000 in free bonus chips. No deposit required.',
      headers: {'From': 'promo@online-casino-wins.com'},
      receivedDate: now.subtract(const Duration(hours: 7)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-008',
      from: 'bonuses@mega-slots.co',
      subject: 'FREE SPINS! 500 Bonus Rounds Waiting',
      body: 'Your exclusive 500 free spins are ready. Start winning now!',
      headers: {'From': 'bonuses@mega-slots.co'},
      receivedDate: now.subtract(const Duration(hours: 8)),
      folderName: 'INBOX',
    ));

    // Phishing attempts
    emails.add(EmailMessage(
      id: 'demo-009',
      from: 'security@paypa1-verification.com',
      subject: 'URGENT: Verify Your PayPal Account Now',
      body: 'Your account will be suspended unless you verify your information immediately.',
      headers: {'From': 'security@paypa1-verification.com'},
      receivedDate: now.subtract(const Duration(hours: 9)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-010',
      from: 'alerts@bank-of-america-secure.net',
      subject: 'Suspicious Activity Detected - Action Required',
      body: 'Click here to verify your identity and secure your account.',
      headers: {'From': 'alerts@bank-of-america-secure.net'},
      receivedDate: now.subtract(const Duration(hours: 10)),
      folderName: 'INBOX',
    ));

    // Adult content spam
    emails.add(EmailMessage(
      id: 'demo-011',
      from: 'members@hot-singles.xxx',
      subject: 'Hot Singles in Your Area Want to Meet You',
      body: 'Join now for free and start chatting with local singles tonight.',
      headers: {'From': 'members@hot-singles.xxx'},
      receivedDate: now.subtract(const Duration(hours: 11)),
      folderName: 'INBOX',
    ));

    // Weight loss / diet spam
    emails.add(EmailMessage(
      id: 'demo-012',
      from: 'info@miracle-weight-loss.com',
      subject: 'Lose 30 Pounds in 30 Days - Guaranteed!',
      body: 'This amazing new supplement will help you lose weight fast. No exercise needed.',
      headers: {'From': 'info@miracle-weight-loss.com'},
      receivedDate: now.subtract(const Duration(hours: 12)),
      folderName: 'INBOX',
    ));

    // Work from home scams
    emails.add(EmailMessage(
      id: 'demo-013',
      from: 'jobs@easy-money-online.biz',
      subject: 'Earn \$5000/Week Working From Home!',
      body: 'No experience needed. Start earning money today from the comfort of your home.',
      headers: {'From': 'jobs@easy-money-online.biz'},
      receivedDate: now.subtract(const Duration(hours: 13)),
      folderName: 'INBOX',
    ));

    // Tech support scams
    emails.add(EmailMessage(
      id: 'demo-014',
      from: 'support@microsoft-security-alert.com',
      subject: 'VIRUS ALERT: Your Computer is Infected',
      body: 'Call our support team immediately to remove viruses from your computer.',
      headers: {'From': 'support@microsoft-security-alert.com'},
      receivedDate: now.subtract(const Duration(hours: 14)),
      folderName: 'INBOX',
    ));

    // Survey / gift card scams
    emails.add(EmailMessage(
      id: 'demo-015',
      from: 'rewards@free-amazon-giftcard.org',
      subject: 'Complete Survey for FREE \$500 Amazon Gift Card',
      body: 'Take our 2-minute survey and receive a \$500 Amazon gift card instantly.',
      headers: {'From': 'rewards@free-amazon-giftcard.org'},
      receivedDate: now.subtract(const Duration(hours: 15)),
      folderName: 'INBOX',
    ));

    // ========================================
    // CATEGORY 2: Marketing/Promotional (15 emails)
    // ========================================

    // Retail promotions
    emails.add(EmailMessage(
      id: 'demo-016',
      from: 'deals@shoppingdeals.com',
      subject: 'Flash Sale: 50% Off Everything!',
      body: 'Limited time offer. Shop now and save big on all items.',
      headers: {'From': 'deals@shoppingdeals.com'},
      receivedDate: now.subtract(const Duration(hours: 16)),
      folderName: 'Promotions',
    ));

    emails.add(EmailMessage(
      id: 'demo-017',
      from: 'promo@fashion-outlet.com',
      subject: 'New Arrivals - Up to 70% Off',
      body: 'Check out our latest collection with massive discounts.',
      headers: {'From': 'promo@fashion-outlet.com'},
      receivedDate: now.subtract(const Duration(hours: 17)),
      folderName: 'Promotions',
    ));

    // Tech company newsletters
    emails.add(EmailMessage(
      id: 'demo-018',
      from: 'newsletter@techgadgets.com',
      subject: 'Weekly Tech Roundup - Best Gadgets of 2026',
      body: 'Here are the top 10 tech gadgets you need to check out this week.',
      headers: {'From': 'newsletter@techgadgets.com'},
      receivedDate: now.subtract(const Duration(hours: 18)),
      folderName: 'Promotions',
    ));

    // Travel deals
    emails.add(EmailMessage(
      id: 'demo-019',
      from: 'offers@travel-deals.com',
      subject: 'Cheap Flights to Europe - Book Now!',
      body: 'Find amazing deals on flights to Europe. Prices starting at \$299.',
      headers: {'From': 'offers@travel-deals.com'},
      receivedDate: now.subtract(const Duration(hours: 19)),
      folderName: 'Promotions',
    ));

    // Food delivery
    emails.add(EmailMessage(
      id: 'demo-020',
      from: 'promo@fooddelivery.com',
      subject: '\$10 Off Your Next Order',
      body: 'Use code SAVE10 at checkout for \$10 off your next food delivery order.',
      headers: {'From': 'promo@fooddelivery.com'},
      receivedDate: now.subtract(const Duration(hours: 20)),
      folderName: 'Promotions',
    ));

    // Streaming service
    emails.add(EmailMessage(
      id: 'demo-021',
      from: 'updates@streaming-service.com',
      subject: 'New Shows This Week on Premium+',
      body: 'Check out the latest additions to our streaming library this week.',
      headers: {'From': 'updates@streaming-service.com'},
      receivedDate: now.subtract(const Duration(hours: 21)),
      folderName: 'Promotions',
    ));

    // Fitness apps
    emails.add(EmailMessage(
      id: 'demo-022',
      from: 'motivation@fitness-app.com',
      subject: 'Your Weekly Fitness Report',
      body: 'You completed 4 workouts this week. Keep up the great work!',
      headers: {'From': 'motivation@fitness-app.com'},
      receivedDate: now.subtract(const Duration(hours: 22)),
      folderName: 'INBOX',
    ));

    // Online courses
    emails.add(EmailMessage(
      id: 'demo-023',
      from: 'learn@online-courses.edu',
      subject: 'New Course: Master Python in 30 Days',
      body: 'Enroll now in our comprehensive Python programming course.',
      headers: {'From': 'learn@online-courses.edu'},
      receivedDate: now.subtract(const Duration(hours: 23)),
      folderName: 'Promotions',
    ));

    // Job boards
    emails.add(EmailMessage(
      id: 'demo-024',
      from: 'alerts@job-board.com',
      subject: '5 New Software Engineer Jobs in Your Area',
      body: 'Check out these new job postings that match your profile.',
      headers: {'From': 'alerts@job-board.com'},
      receivedDate: now.subtract(const Duration(days: 1)),
      folderName: 'INBOX',
    ));

    // Social media notifications
    emails.add(EmailMessage(
      id: 'demo-025',
      from: 'notify@social-network.com',
      subject: 'You have 12 new notifications',
      body: 'See who liked your posts and sent you friend requests.',
      headers: {'From': 'notify@social-network.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 1)),
      folderName: 'INBOX',
    ));

    // Cloud storage
    emails.add(EmailMessage(
      id: 'demo-026',
      from: 'storage@cloud-provider.com',
      subject: 'You are running out of storage space',
      body: 'Upgrade to premium for 100GB of additional storage.',
      headers: {'From': 'storage@cloud-provider.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 2)),
      folderName: 'INBOX',
    ));

    // News subscriptions
    emails.add(EmailMessage(
      id: 'demo-027',
      from: 'daily@news-digest.com',
      subject: 'Your Daily News Briefing - February 9, 2026',
      body: 'Top stories from around the world delivered to your inbox.',
      headers: {'From': 'daily@news-digest.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 3)),
      folderName: 'INBOX',
    ));

    // Blog subscriptions
    emails.add(EmailMessage(
      id: 'demo-028',
      from: 'posts@tech-blog.com',
      subject: 'New Post: 10 Tips for Better Code Reviews',
      body: 'Read our latest article on improving your code review process.',
      headers: {'From': 'posts@tech-blog.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 4)),
      folderName: 'INBOX',
    ));

    // Banking newsletters
    emails.add(EmailMessage(
      id: 'demo-029',
      from: 'newsletter@mybank.com',
      subject: 'New Features in Mobile Banking',
      body: 'Check out the latest updates to our mobile banking app.',
      headers: {'From': 'newsletter@mybank.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 5)),
      folderName: 'INBOX',
    ));

    // Credit card offers
    emails.add(EmailMessage(
      id: 'demo-030',
      from: 'offers@credit-card-company.com',
      subject: 'Pre-Approved for Platinum Card',
      body: 'You have been pre-approved for our premium platinum credit card.',
      headers: {'From': 'offers@credit-card-company.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 6)),
      folderName: 'Promotions',
    ));

    // ========================================
    // CATEGORY 3: Legitimate Business (10 emails)
    // ========================================

    // Project management
    emails.add(EmailMessage(
      id: 'demo-031',
      from: 'notifications@project-tool.com',
      subject: 'Task Assigned: Update Sprint Planning Doc',
      body: 'John Smith has assigned you a new task in Project Alpha.',
      headers: {'From': 'notifications@project-tool.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 7)),
      folderName: 'INBOX',
    ));

    // GitHub notifications
    emails.add(EmailMessage(
      id: 'demo-032',
      from: 'noreply@github.com',
      subject: '[myrepo] Pull Request #42: Fix authentication bug',
      body: 'User123 opened a new pull request for your review.',
      headers: {'From': 'noreply@github.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 8)),
      folderName: 'INBOX',
    ));

    // Calendar reminders
    emails.add(EmailMessage(
      id: 'demo-033',
      from: 'calendar@workspace.com',
      subject: 'Reminder: Team Meeting in 1 hour',
      body: 'Your meeting "Weekly Team Sync" starts at 2:00 PM.',
      headers: {'From': 'calendar@workspace.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 9)),
      folderName: 'INBOX',
    ));

    // HR notifications
    emails.add(EmailMessage(
      id: 'demo-034',
      from: 'hr@company.com',
      subject: 'Benefits Enrollment Period Ending Soon',
      body: 'Complete your benefits enrollment by Friday, February 14th.',
      headers: {'From': 'hr@company.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 10)),
      folderName: 'INBOX',
    ));

    // IT department
    emails.add(EmailMessage(
      id: 'demo-035',
      from: 'it-support@company.com',
      subject: 'Scheduled Maintenance: Saturday 2AM-4AM',
      body: 'Network services will be unavailable during scheduled maintenance window.',
      headers: {'From': 'it-support@company.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 11)),
      folderName: 'INBOX',
    ));

    // Payroll
    emails.add(EmailMessage(
      id: 'demo-036',
      from: 'payroll@company.com',
      subject: 'Payroll Direct Deposit Confirmation',
      body: 'Your payroll has been processed. Funds will be available on February 15th.',
      headers: {'From': 'payroll@company.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 12)),
      folderName: 'INBOX',
    ));

    // Team communication
    emails.add(EmailMessage(
      id: 'demo-037',
      from: 'sarah.johnson@company.com',
      subject: 'Q1 Planning Meeting Notes',
      body: 'Here are the notes from today planning meeting. Please review and add comments.',
      headers: {'From': 'sarah.johnson@company.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 13)),
      folderName: 'INBOX',
    ));

    // Client communication
    emails.add(EmailMessage(
      id: 'demo-038',
      from: 'client@clientcompany.com',
      subject: 'Re: Project Timeline Update',
      body: 'Thanks for the update. The new timeline works well for us.',
      headers: {'From': 'client@clientcompany.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 14)),
      folderName: 'INBOX',
    ));

    // Vendor communication
    emails.add(EmailMessage(
      id: 'demo-039',
      from: 'sales@vendor.com',
      subject: 'Invoice #12345 for Software License Renewal',
      body: 'Please find attached invoice for your annual software license renewal.',
      headers: {'From': 'sales@vendor.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 15)),
      folderName: 'INBOX',
    ));

    // Security alerts (legitimate)
    emails.add(EmailMessage(
      id: 'demo-040',
      from: 'security@company.com',
      subject: 'New Sign-In from Windows Device',
      body: 'We noticed a new sign-in to your account from a Windows device in Seattle, WA.',
      headers: {'From': 'security@company.com'},
      receivedDate: now.subtract(const Duration(days: 1, hours: 16)),
      folderName: 'INBOX',
    ));

    // ========================================
    // CATEGORY 4: Personal (10 emails)
    // ========================================

    // Family
    emails.add(EmailMessage(
      id: 'demo-041',
      from: 'mom@family.com',
      subject: 'Dinner this Sunday?',
      body: 'Hi honey, are you free for dinner this Sunday? Dad wants to try the new Italian place.',
      headers: {'From': 'mom@family.com'},
      receivedDate: now.subtract(const Duration(days: 2)),
      folderName: 'INBOX',
    ));

    // Friends
    emails.add(EmailMessage(
      id: 'demo-042',
      from: 'mike@gmail.com',
      subject: 'Game night this Friday',
      body: 'Hey! Want to come over for board games on Friday? Bringing the crew.',
      headers: {'From': 'mike@gmail.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 1)),
      folderName: 'INBOX',
    ));

    // Online order confirmations
    emails.add(EmailMessage(
      id: 'demo-043',
      from: 'orders@amazon.com',
      subject: 'Your Order #123-4567890-1234567 has shipped',
      body: 'Your package will arrive on February 12th. Track your shipment here.',
      headers: {'From': 'orders@amazon.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 2)),
      folderName: 'INBOX',
    ));

    // Shipping notifications
    emails.add(EmailMessage(
      id: 'demo-044',
      from: 'tracking@fedex.com',
      subject: 'Package Delivered',
      body: 'Your FedEx package was delivered and left at your front door at 2:35 PM.',
      headers: {'From': 'tracking@fedex.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 3)),
      folderName: 'INBOX',
    ));

    // Utility bills
    emails.add(EmailMessage(
      id: 'demo-045',
      from: 'billing@electric-company.com',
      subject: 'Your February Electric Bill is Ready',
      body: 'Your electric bill for February is \$125.67. Pay by February 25th.',
      headers: {'From': 'billing@electric-company.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 4)),
      folderName: 'INBOX',
    ));

    // Healthcare
    emails.add(EmailMessage(
      id: 'demo-046',
      from: 'appointments@healthclinic.com',
      subject: 'Appointment Reminder: Dr. Smith - Feb 15',
      body: 'This is a reminder of your appointment with Dr. Smith on February 15th at 10:00 AM.',
      headers: {'From': 'appointments@healthclinic.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 5)),
      folderName: 'INBOX',
    ));

    // School/Education
    emails.add(EmailMessage(
      id: 'demo-047',
      from: 'registrar@university.edu',
      subject: 'Spring 2026 Course Registration Opens Monday',
      body: 'Registration for spring semester courses opens Monday, February 10th at 8:00 AM.',
      headers: {'From': 'registrar@university.edu'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 6)),
      folderName: 'INBOX',
    ));

    // Community/HOA
    emails.add(EmailMessage(
      id: 'demo-048',
      from: 'board@hoa.org',
      subject: 'HOA Board Meeting Minutes - January 2026',
      body: 'Please review the minutes from last month HOA board meeting.',
      headers: {'From': 'board@hoa.org'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 7)),
      folderName: 'INBOX',
    ));

    // Subscription renewals
    emails.add(EmailMessage(
      id: 'demo-049',
      from: 'billing@magazine-subscription.com',
      subject: 'Your Subscription Expires Soon',
      body: 'Your magazine subscription will expire on February 28th. Renew now to continue.',
      headers: {'From': 'billing@magazine-subscription.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 8)),
      folderName: 'INBOX',
    ));

    // Charity/Non-profit
    emails.add(EmailMessage(
      id: 'demo-050',
      from: 'donate@charity.org',
      subject: 'Your 2025 Donation Receipt for Tax Purposes',
      body: 'Thank you for your generous donations in 2025. Here is your tax receipt.',
      headers: {'From': 'donate@charity.org'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 9)),
      folderName: 'INBOX',
    ));

    // ========================================
    // CATEGORY 5: "No Rule" Examples (5 emails)
    // ========================================

    // Legitimate senders that don't match any rule
    emails.add(EmailMessage(
      id: 'demo-051',
      from: 'contact@new-vendor.com',
      subject: 'Introduction: Partnership Opportunity',
      body: 'Hello, we would like to discuss a potential partnership opportunity.',
      headers: {'From': 'contact@new-vendor.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 10)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-052',
      from: 'recruiter@tech-company.com',
      subject: 'Exciting Career Opportunity',
      body: 'I came across your profile and think you would be a great fit for our team.',
      headers: {'From': 'recruiter@tech-company.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 11)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-053',
      from: 'info@conference2026.com',
      subject: 'Speaker Invitation: Tech Summit 2026',
      body: 'We would be honored to have you as a speaker at our annual tech summit.',
      headers: {'From': 'info@conference2026.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 12)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-054',
      from: 'editor@tech-journal.com',
      subject: 'Article Submission Acknowledgment',
      body: 'Thank you for submitting your article. We will review it and respond within 2 weeks.',
      headers: {'From': 'editor@tech-journal.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 13)),
      folderName: 'INBOX',
    ));

    emails.add(EmailMessage(
      id: 'demo-055',
      from: 'organizer@meetup.com',
      subject: 'New Meetup Event: Flutter Developers Group',
      body: 'Join us for our monthly Flutter developers meetup on February 20th.',
      headers: {'From': 'organizer@meetup.com'},
      receivedDate: now.subtract(const Duration(days: 2, hours: 14)),
      folderName: 'INBOX',
    ));

    return emails;
  }

  /// Get demo folder names
  static List<String> getDemoFolders() {
    return ['INBOX', 'Promotions', 'Spam', 'Junk', 'Trash'];
  }
}

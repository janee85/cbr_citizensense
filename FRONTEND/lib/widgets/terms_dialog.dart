import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'seal_logo.dart';

// DRAFT text for the project. Have your adviser / the city's data protection
// officer review it before real deployment.
const _sections = <(String, String)>[
  ('1. Acceptance',
      'By creating an account or filing a complaint on Cabadbaran CitizenSense, you agree to these Terms of Use and the Data Privacy Notice below. If you do not agree, please do not use the system.'),
  ('2. Accounts and roles',
      'Each person may keep one account and must give true information. Your role is set by your email domain: @gmail.com for citizens, @staff.com for office staff, and @admin.com for administrators. Staff and administrator accounts are only for authorized City Government personnel. Keep your password private; you are responsible for activity under your account.'),
  ('3. Filing complaints',
      'File only genuine concerns about city services or public matters. False, abusive, harassing, or prank complaints may be removed and your account may be restricted. CitizenSense is not an emergency hotline. For fire, injury, or danger to life, call 911 or your local emergency hotline first.'),
  ('4. Automatic classification',
      'A machine-learning and natural-language-processing component reads your complaint to suggest its category, sentiment, and priority level (Low, Medium, High, or Critical). These results are suggestions that help city offices sort complaints faster. Authorized staff may review and correct them, and the result does not guarantee any particular action or response time.'),
  ('5. Personal data we collect',
      'Your name, email address, role, the complaint details you write (title, description, category, location, and chosen office), any attachments you add, and account activity such as log-ins and status updates.'),
  ('6. How your data is used and shared',
      'Your data is used to run your account, classify and route your complaint to the chosen office, let staff respond, notify you of status changes, and produce reports. Reports use summarized data. Your complaint is visible only to you, the assigned office staff, and authorized administrators. We do not sell your personal data. Processing follows the Data Privacy Act of 2012 (Republic Act No. 10173).'),
  ('7. Your rights',
      'You may ask to access, correct, or object to the processing of your personal data, and to request deletion where the law allows. Send requests through the City Government of Cabadbaran and its Data Protection Officer.'),
  ('8. Security and retention',
      'Data travels over encrypted HTTPS, passwords are stored hashed, and access is limited by role. Records are kept as long as needed to handle complaints and meet legal and audit requirements, then archived or deleted under city policy.'),
  ('9. Changes',
      'These terms may be updated. Continued use of CitizenSense after an update means you accept the new version.'),
];

/// Returns true when the person taps "I agree".
Future<bool?> showTermsDialog(BuildContext context) =>
    showDialog<bool>(context: context, builder: (_) => const _TermsDialog());

class _TermsDialog extends StatelessWidget {
  const _TermsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 660),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(children: [
              const SealLogo(size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Terms of Use and Data Privacy Notice',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          const Divider(height: 1, color: AppColors.line),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(22),
              shrinkWrap: true,
              children: [
                for (final s in _sections) ...[
                  Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(s.$2, style: const TextStyle(height: 1.5, color: AppColors.ink)),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('I agree'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

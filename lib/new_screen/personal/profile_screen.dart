import 'package:flutter/material.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/const/custom_textstyle.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Flexible(
                  flex: 3,
                  child: Row(children: [
                    const SizedBox(width: 16),
                    GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: const Icon(Icons.close)),
                    const Spacer(),
                    const Text(
                      'Profile',
                      style: CustomTextStyle.h4Bold,
                    )
                  ]),
                ),
                const Flexible(flex: 2, child: SizedBox()),
                // SizedBox(),
              ],
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    child: Icon(
                      Icons.person,
                      size: 28,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'David Nguyen',
                        style: CustomTextStyle.h5Medium,
                      ),
                      Text('davidnguyen@gmail.com'),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                'Help',
                style: CustomTextStyle.captionMedium
                    .copyWith(color: CustomColor.neutralBlack50),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'FAQ',
                    style: CustomTextStyle.bodyMedium,
                  ),
                  Divider(
                    thickness: 0.3,
                  ),
                  Text(
                    'Hotline',
                    style: CustomTextStyle.bodyMedium,
                  ),
                  Divider(
                    thickness: 0.3,
                  ),
                  Text(
                    'Support Center',
                    style: CustomTextStyle.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                'Device',
                style: CustomTextStyle.captionMedium
                    .copyWith(color: CustomColor.neutralBlack50),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Interface Settings',
                    style: CustomTextStyle.bodyMedium,
                  ),
                  Divider(
                    thickness: 0.3,
                  ),
                  Text(
                    'Upgrade firmware',
                    style: CustomTextStyle.bodyMedium,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: CustomColor.neutralBlack50,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Log out'),
            )
          ],
        ),
      ),
    );
  }
}

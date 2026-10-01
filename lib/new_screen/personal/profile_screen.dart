import 'package:flutter/material.dart';
import 'package:new_renitek/const/custom_color.dart';
import 'package:new_renitek/const/custom_textstyle.dart';
import 'package:new_renitek/providers/app_provider.dart';
import 'package:new_renitek/service/check_firmware_service.dart';
import 'package:new_renitek/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24),
              _HeaderSection(),
              SizedBox(height: 12),
              _BleModeSettingCard(),
              SizedBox(height: 24),
              _FirmwareDownloadSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Settings',
            textAlign: TextAlign.center,
            style: CustomTextStyle.h4Bold,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            'Device',
            style: CustomTextStyle.bodyMedium
                .copyWith(color: CustomColor.neutralBlack50),
          ),
        ),
      ],
    );
  }
}

class _BleModeSettingCard extends StatelessWidget {
  const _BleModeSettingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'BLE Mode',
                  style: CustomTextStyle.bodyMedium,
                ),
              ),
              Switch(
                value: provider.isExpertMode,
                onChanged: provider.toggleExpertMode,
                activeThumbColor: CustomColor.primaryColor,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FirmwareDownloadSection extends StatelessWidget {
  const _FirmwareDownloadSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download, color: Colors.white),
            onPressed: () => _downloadFirmwares(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomColor.primaryColor,
              minimumSize: const Size.fromHeight(50),
            ),
            label: const Text(
              'Download Latest FW (Server)',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_alt, color: CustomColor.primaryColor),
            onPressed: () => _downloadFirmwares(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: CustomColor.primaryColor,
              side: const BorderSide(color: CustomColor.primaryColor),
              minimumSize: const Size.fromHeight(50),
            ),
            label: const Text(
              'Download Backup (Stable)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFirmwares(BuildContext context, bool useApi) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Downloading data. Please wait...')),
          ],
        ),
      ),
    );

    try {
      final successCount =
          await CheckFirmwareService.downloadAndCacheFirmwares(useApi);

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        if (successCount == -1) {
          SnackbarHelper.showInfo(context, 'Notice', 'No firmware found.');
        } else if (successCount > 0) {
          final message = useApi
              ? 'Successfully downloaded $successCount latest FW files from the server!'
              : 'Successfully downloaded $successCount backup FW files!';
          SnackbarHelper.showSuccess(context, 'Success', message);
        } else {
          SnackbarHelper.showError(context, 'Download Failed',
              'No files were downloaded. Please check your network connection!');
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Connection Error',
            'Please check your Internet connection!');
      }
    }
  }
}

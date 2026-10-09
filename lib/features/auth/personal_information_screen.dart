import 'package:flutter/material.dart';
import 'registration_step1_screen.dart';

export 'registration_step1_screen.dart';
export 'vehicle_details_screen.dart';
export 'documents_upload_step_screen.dart';

class PersonalInformationScreen extends StatelessWidget {
  final bool isProviderDriver;

  const PersonalInformationScreen({super.key, this.isProviderDriver = false});

  @override
  Widget build(BuildContext context) {
    return RegistrationStep1Screen(isProviderDriver: isProviderDriver);
  }
}

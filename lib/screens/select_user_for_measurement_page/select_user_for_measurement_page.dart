import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import './select_user_for_measurement_page_functions.dart';
import './widgets/people_list.dart';

class SelectUserForMeasurementPage extends StatefulWidget {
  const SelectUserForMeasurementPage({super.key});

  @override
  State<SelectUserForMeasurementPage> createState() => _SelectUserForMeasurementPageState();
}

class _SelectUserForMeasurementPageState extends State<SelectUserForMeasurementPage> {
  late Stream<List<Map<String, dynamic>>> _peopleStream;

  @override
  void initState() {
    super.initState();
    _peopleStream = SelectUserForMeasurementFunctions.streamPeople();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).homeUsers),
      ),
      body: PeopleList(stream: _peopleStream),
    );
  }
}
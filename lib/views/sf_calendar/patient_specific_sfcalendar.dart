import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dentistry/config/developer_options.dart';
import 'package:flutter_dentistry/config/global_usage.dart';
import 'package:flutter_dentistry/config/language_provider.dart';
import 'package:flutter_dentistry/config/settings_provider.dart';
import 'package:flutter_dentistry/config/translations.dart';
import 'package:flutter_dentistry/models/db_conn.dart';
import 'package:flutter_dentistry/views/patients/patient_info.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart' as intl2;

// ignore: prefer_typing_uninitialized_variables
var selectedLanguage;
// ignore: prefer_typing_uninitialized_variables
var isEnglish;
var selectedCalType;
var isGregorian;

// This is shows snackbar when called
void _onShowSnack(Color backColor, String msg, BuildContext context) {
  Flushbar(
    backgroundColor: backColor,
    flushbarStyle: FlushbarStyle.GROUNDED,
    flushbarPosition: FlushbarPosition.BOTTOM,
    messageText: Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    ),
    duration: const Duration(seconds: 3),
  ).show(context);
}

class CalendarAppForSpecificPatient extends StatelessWidget {
  const CalendarAppForSpecificPatient({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fetch translations keys based on the selected language.
    var languageProvider = Provider.of<LanguageProvider>(context);
    selectedLanguage = languageProvider.selectedLanguage;
    isEnglish = selectedLanguage == 'English';
    // Choose calendar type from its provider
    var calTypeProvider = Provider.of<SettingsProvider>(context);
    selectedCalType = calTypeProvider.selectedDateType;
    isGregorian = selectedCalType == 'میلادی';
    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              '${translations[selectedLanguage]?['SchedApptFor'] ?? ''} ${PatientInfo.firstName} ${PatientInfo.lastName}'),
          leading: IconButton(
            splashRadius: 25.0,
            onPressed: () => Navigator.pop(context),
            icon: const BackButtonIcon(),
          ),
        ),
        body: const CalendarPage(),
      ),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late int? serviceId;
  late int? staffId;
  // This is to fetch staff list
  List<Map<String, dynamic>> staffList = [];
  // This list is to be assigned services
  List<Map<String, dynamic>> services = [];
  late List<PatientAppointment> _appointments;
  final _calFormKey = GlobalKey<FormState>();
// Create an instance GlobalUsage to be access its method
  final GlobalUsage _gu = GlobalUsage();
  // These variable are used for editing schedule appointment
  int selectedStaffId = 0;
  int selectedServiceId = 0;

  @override
  void initState() {
    super.initState();
    _gu.fetchStaff().then((staff) {
      setState(() {
        staffList = staff;
        staffId = staffList.isNotEmpty
            ? int.parse(staffList[0]['staff_ID'])
            : selectedStaffId;
      });
    });

    // Access the function to fetch services
    _gu.fetchServices().then((service) {
      setState(() {
        services = service;
        serviceId = services.isNotEmpty
            ? int.parse(services[0]['ser_ID'])
            : selectedServiceId;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppointmentDataSource>(
      future: _getCalendarDataSource(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Show a loading spinner while waiting
        } else if (snapshot.hasError) {
          return Text(
              'Error: ${snapshot.error}'); // Show error message if something went wrong
        } else {
          return SfCalendar(
            allowViewNavigation: true,
            allowDragAndDrop: true,
            dataSource: snapshot.data,
            view: CalendarView.day,
            allowedViews: const [
              CalendarView.day,
              CalendarView.month,
              CalendarView.week,
              CalendarView.workWeek,
              CalendarView.schedule
            ],
            onTap: (CalendarTapDetails details) {
              if (details.targetElement == CalendarElement.calendarCell) {
                DateTime? selectedDate = details.date;
                _scheduleAppointment(context, selectedDate!, () {
                  setState(() {});
                });
              } else if (details.targetElement == CalendarElement.appointment) {
                // Access members of PatientAppointment class
                Meeting meeting = details.appointments![0];
                PatientAppointment appointment = meeting.patientAppointment;
                int aptId = appointment.apptId;
                int serviceID = appointment.serviceID;
                int dentistID = appointment.staffID;
                String dentistFName = appointment.dentistFName;
                String dentistLName = appointment.dentistLName.isEmpty
                    ? ''
                    : appointment.dentistLName;
                String serviceName = appointment.serviceName;
                DateTime scheduleTime = appointment.visitTime;
                String description =
                    appointment.comments.isEmpty ? '' : appointment.comments;
                String notifFreq = appointment.notifFreq;
                // Call this function to see more details of an schedule appointment
                _showAppoinmentDetails(
                    context,
                    dentistID,
                    serviceID,
                    aptId,
                    dentistFName,
                    dentistLName,
                    serviceName,
                    scheduleTime,
                    description,
                    notifFreq);
              }
            },
          );
        }
      },
    );
  }

// Create this function to schedule an appointment
  _scheduleAppointment(
      BuildContext context, DateTime selectedDate, Function refresh) async {
    DateTime selectedDateTime = DateTime.now();
    TextEditingController apptdatetimeController = TextEditingController();
    TextEditingController commentController = TextEditingController();
    String notifFrequency = '30 Minutes';
    int? patientId = PatientInfo.patID;

    if (isGregorian) {
      intl2.DateFormat formatter = intl2.DateFormat('yyyy-MM-dd HH:mm');
      apptdatetimeController.text = formatter.format(selectedDate);
    } else {
      // Parse the string into a DateTime object
      DateTime gregorian = DateTime.parse(selectedDate.toString());
      // Convert the DateTime object to a Jalali date
      Jalali jalali = Jalali.fromDateTime(gregorian);
      DateTime hijriDT = DateTime(jalali.year, jalali.month, jalali.day,
          gregorian.hour, gregorian.minute);
      final intl2.DateFormat formatter = intl2.DateFormat('yyyy-MM-dd HH:mm');
      apptdatetimeController.text = formatter.format(hijriDT);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: AlertDialog(
                title: Text(
                    '${translations[selectedLanguage]?['SchdAppt'] ?? ''}${PatientInfo.firstName} ${PatientInfo.lastName}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(color: Colors.blue)),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.35,
                  child: SingleChildScrollView(
                    child: Form(
                      key: _calFormKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['SelectDentist'] ??
                                    '',
                                labelStyle:
                                    const TextStyle(color: Colors.blueAccent),
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide:
                                        BorderSide(color: Colors.blueAccent)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                                errorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15.0)),
                                    borderSide: BorderSide(color: Colors.red)),
                                focusedErrorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15.0)),
                                    borderSide: BorderSide(
                                        color: Colors.red, width: 1.5)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: Container(
                                  height: 26.0,
                                  padding: EdgeInsets.zero,
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    value: staffId.toString(),
                                    style: const TextStyle(color: Colors.black),
                                    items: staffList.map((staff) {
                                      return DropdownMenuItem<String>(
                                        value: staff['staff_ID'],
                                        alignment: Alignment.centerRight,
                                        child: Text(staff['firstname'] +
                                            ' ' +
                                            staff['lastname']),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        staffId = int.parse(newValue!);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['َDentalService'] ??
                                    '',
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: SizedBox(
                                  height: 26.0,
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    value: serviceId.toString(),
                                    items: services.map((service) {
                                      return DropdownMenuItem<String>(
                                        value: service['ser_ID'],
                                        alignment: Alignment.centerRight,
                                        child: Text(service['ser_name']),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        // Assign the selected service id into the static one.
                                        serviceId = int.parse(newValue!);
                                        print('Selected service: $serviceId');
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: TextFormField(
                              textDirection: TextDirection.ltr,
                              controller: apptdatetimeController,
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return translations[selectedLanguage]
                                          ?['ApptDTRequired'] ??
                                      '';
                                }
                                return null;
                              },
                              readOnly: true,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['ApptDateTime'] ??
                                    '',
                                suffixIcon: const Icon(Icons.access_time),
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                                errorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.red)),
                                focusedErrorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(
                                        color: Colors.red, width: 1.5)),
                              ),
                              onTap: () async {
                                if (isGregorian) {
                                  final DateTime? pickedDate =
                                      await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate != null) {
                                    // ignore: use_build_context_synchronously
                                    final TimeOfDay? pickedTime =
                                        // ignore: use_build_context_synchronously
                                        await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (pickedTime != null) {
                                      selectedDateTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                      final intl2.DateFormat formatter =
                                          intl2.DateFormat("yyyy-MM-dd HH:mm");
                                      String formattedDateTime =
                                          formatter.format(selectedDateTime);
                                      apptdatetimeController.text =
                                          formattedDateTime;
                                    }
                                  }
                                } else {
                                  // Set Hijry/Jalali calendar
                                  Jalali? hijriDate =
                                      await showPersianDatePicker(
                                          context: context,
                                          initialDate: Jalali.now(),
                                          firstDate: Jalali(1395, 8),
                                          lastDate: Jalali(1450, 9));
                                  if (hijriDate != null) {
                                    final TimeOfDay? pickedTime =
                                        // ignore: use_build_context_synchronously
                                        await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (pickedTime != null) {
                                      selectedDateTime = DateTime(
                                        hijriDate.year,
                                        hijriDate.month,
                                        hijriDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                      // Fortmat to display a more user-friendly manner in the field like: 2024-05-04 07:00
                                      final intl2.DateFormat formatter =
                                          intl2.DateFormat('yyyy-MM-dd HH:mm');
                                      String formattedDateTime =
                                          formatter.format(selectedDateTime);
                                      apptdatetimeController.text =
                                          formattedDateTime;
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: TextFormField(
                              controller: commentController,
                              validator: (value) {
                                if (value!.isNotEmpty) {
                                  if (value.length < 5 || value.length > 40) {
                                    return translations[selectedLanguage]
                                            ?['OtherDDLLength'] ??
                                        '';
                                  }
                                  return null;
                                }
                                return null;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(GlobalUsage.allowedEPChar))
                              ],
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['RetDetails'] ??
                                    '',
                                suffixIcon:
                                    const Icon(Icons.description_outlined),
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                                errorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.red)),
                                focusedErrorBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide:
                                      BorderSide(color: Colors.red, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                suffixIcon:
                                    Icon(Icons.notifications_active_outlined),
                                border: OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.red),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: SizedBox(
                                  height: 26.0,
                                  child: DropdownButton(
                                    // isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    value: notifFrequency,
                                    items: <String>[
                                      '30 Minutes',
                                      '1 Hour',
                                      '2 Hours',
                                      '6 Hours',
                                      '12 Hours',
                                      '1 Day',
                                    ].map<DropdownMenuItem<String>>(
                                        (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        notifFrequency = newValue!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                actions: <Widget>[
                  Row(
                    mainAxisAlignment: isEnglish
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                            translations[selectedLanguage]?['CancelBtn'] ?? ''),
                      ),
                      (Features.upcomingAppointment)
                          ? ElevatedButton(
                              child: Text(translations[selectedLanguage]
                                      ?['AddBtn'] ??
                                  ''),
                              onPressed: () async {
                                if (_calFormKey.currentState!.validate()) {
                                  try {
                                    String schedApptDT;
                                    if (isGregorian) {
                                      schedApptDT = apptdatetimeController.text;
                                    } else {
                                      // First we separate date and time
                                      List<String> shamsiParts =
                                          apptdatetimeController.text
                                              .split(' ');
                                      String shamsiDate = shamsiParts[0];
                                      String shamsiTime = shamsiParts[1];
                                      // Now we separate year, month, day in shamsi date
                                      List<String> dateParts =
                                          shamsiDate.split('-');
                                      // Convert shamsi to gregorian
                                      Jalali jalali = Jalali(
                                          int.parse(dateParts[0]),
                                          int.parse(dateParts[1]),
                                          int.parse(dateParts[2]));

                                      // Fetch it into Date type
                                      Date gregDate = jalali.toGregorian();
                                      // We need datetime type to format it
                                      DateTime gregDateTime = DateTime(
                                          gregDate.year,
                                          gregDate.month,
                                          gregDate.day);

                                      // Format it to be in yyyy-mm-dd
                                      intl2.DateFormat formatter =
                                          intl2.DateFormat('yyyy-MM-dd');
                                      schedApptDT =
                                          '${formatter.format(gregDateTime)} $shamsiTime';
                                    }

                                    final conn = await onConnToSqliteDb();
                                    final results = await conn.rawInsert(
                                        'INSERT INTO appointments (pat_ID, service_ID, meet_date, staff_ID, status, notification, details) VALUES (?, ?, ?, ?, ?, ?, ?)',
                                        [
                                          patientId,
                                          serviceId,
                                          schedApptDT,
                                          staffId,
                                          'Pending',
                                          notifFrequency,
                                          commentController.text.isEmpty
                                              ? null
                                              : commentController.text
                                        ]);
                                    if (results > 0) {
                                      // ignore: use_build_context_synchronously
                                      Navigator.of(context).pop();
                                      // ignore: use_build_context_synchronously
                                      _onShowSnack(
                                          Colors.green,
                                          translations[selectedLanguage]
                                                  ?['SchedSuccessMsg'] ??
                                              '',
                                          context);
                                      refresh();
                                    }
                                  } catch (e) {
                                    print('Appointment scheduling failed: $e');
                                  }
                                }
                              },
                            )
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.workspace_premium_outlined,
                                  color: Colors.red),
                              onPressed: () => _onShowSnack(
                                  Colors.red,
                                  translations[selectedLanguage]
                                          ?['PremAppPurchase'] ??
                                      '',
                                  context),
                              label: Text(translations[selectedLanguage]
                                      ?['AddBtn'] ??
                                  ''),
                            ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// This function is to show scheduled appointment details
  _showAppoinmentDetails(
      BuildContext context,
      int staffID,
      int serviceId,
      int aptId,
      String firstName,
      String lastName,
      String service,
      DateTime time,
      String description,
      String frequency) async {
    String formattedTime;

    if (isGregorian) {
      intl2.DateFormat formatter = intl2.DateFormat('yyyy-MM-dd HH:mm');
      formattedTime = formatter.format(time);
    } else {
      // Parse the string into a DateTime object
      DateTime gregorian = DateTime.parse(time.toString());
      // Convert the DateTime object to a Jalali date
      Jalali jalali = Jalali.fromDateTime(gregorian);
      DateTime hijriDT = DateTime(jalali.year, jalali.month, jalali.day,
          gregorian.hour, gregorian.minute);
      final intl2.DateFormat formatter = intl2.DateFormat('yyyy-MM-dd HH:mm');
      formattedTime = formatter.format(hijriDT);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment:
                isEnglish ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              IconButton(
                  splashRadius: 25.0,
                  onPressed: () {
                    Navigator.pop(context);
                    _editAppointmentDetails(context, staffID, serviceId, aptId,
                        time, frequency, description, () {
                      setState(() {});
                    });
                  },
                  icon: const Icon(Icons.edit_outlined,
                      size: 18.0, color: Colors.blue)),
              const SizedBox(width: 10.0),
              IconButton(
                  splashRadius: 25.0,
                  onPressed: () {
                    Navigator.pop(context);
                    _onDeleteAppointment(context, aptId, () {
                      setState(() {});
                    });
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 18.0, color: Colors.blue)),
            ],
          ),
          content: Directionality(
            textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.3,
              height: MediaQuery.of(context).size.height * 0.35,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            color: Colors.grey),
                        const SizedBox(width: 15.0),
                        Text(formattedTime, textDirection: TextDirection.ltr)
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.title_outlined, color: Colors.grey),
                        const SizedBox(width: 15.0),
                        Text(service.toString()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.person_3_outlined, color: Colors.grey),
                        const SizedBox(width: 15.0),
                        Text('$firstName $lastName'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined,
                            color: Colors.grey),
                        const SizedBox(width: 15.0),
                        Text(frequency),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outlined, color: Colors.grey),
                        const SizedBox(width: 15.0),
                        SizedBox(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: Text(description))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment:
                  isEnglish ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                ElevatedButton(
                  child: Text(translations[selectedLanguage]?['Okay'] ?? ''),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            )
          ],
        );
      },
    );
  }

// This function is to edit scheduled appointment details
  _editAppointmentDetails(
      BuildContext context,
      int dentistID,
      int selectedSerId,
      int apptId,
      DateTime selectedDate,
      String notifFreq,
      String description,
      Function refresh) async {
    DateTime selectedDateTime = DateTime.now();
    TextEditingController editApptTimeController = TextEditingController();
    TextEditingController editCommentController = TextEditingController();
    if (isGregorian) {
      intl2.DateFormat formatter = intl2.DateFormat('yyyy-MM-dd HH:mm');
      editApptTimeController.text = formatter.format(selectedDate);
    } else {
      // Parse the string into a DateTime object
      DateTime gregorian = DateTime.parse(selectedDate.toString());
      // Convert the DateTime object to a Jalali date
      Jalali jalali = Jalali.fromDateTime(gregorian);
      DateTime hijriDT = DateTime(jalali.year, jalali.month, jalali.day,
          gregorian.hour, gregorian.minute);
      final intl2.DateFormat formatter = intl2.DateFormat('yyyy-MM-dd HH:mm');
      editApptTimeController.text = formatter.format(hijriDT);
    }

    int? patientId = PatientInfo.patID;
    editCommentController.text = description;

// Assign this argument to selectedStaffId to display this dentist in edit dialogbox.
    selectedStaffId = dentistID;
    selectedServiceId = selectedSerId;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: AlertDialog(
                title: Text(translations[selectedLanguage]?['EditAppt'] ?? ''),
                content: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: MediaQuery.of(context).size.width * 0.35,
                  child: SingleChildScrollView(
                    child: Form(
                      key: _calFormKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['SelectDentist'] ??
                                    '',
                                labelStyle:
                                    const TextStyle(color: Colors.blueAccent),
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide:
                                        BorderSide(color: Colors.blueAccent)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                                errorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15.0)),
                                    borderSide: BorderSide(color: Colors.red)),
                                focusedErrorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15.0)),
                                    borderSide: BorderSide(
                                        color: Colors.red, width: 1.5)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: Container(
                                  height: 26.0,
                                  padding: EdgeInsets.zero,
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    value: selectedStaffId.toString(),
                                    style: const TextStyle(color: Colors.black),
                                    items: staffList.map((staff) {
                                      return DropdownMenuItem<String>(
                                        value: staff['staff_ID'],
                                        alignment: Alignment.centerRight,
                                        child: Text(staff['firstname'] +
                                            ' ' +
                                            staff['lastname']),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedStaffId = int.parse(newValue!);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['َDentalService'] ??
                                    '',
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: SizedBox(
                                  height: 26.0,
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    value: selectedServiceId.toString(),
                                    items: services.map((service) {
                                      return DropdownMenuItem<String>(
                                        value: service['ser_ID'],
                                        alignment: Alignment.centerRight,
                                        child: Text(service['ser_name']),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        // Assign the selected service id into the static one.
                                        selectedServiceId =
                                            int.parse(newValue!);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: TextFormField(
                              textDirection: TextDirection.ltr,
                              controller: editApptTimeController,
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return translations[selectedLanguage]
                                          ?['ApptDTRequired'] ??
                                      '';
                                }
                                return null;
                              },
                              readOnly: true,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['ApptDateTime'] ??
                                    '',
                                suffixIcon: const Icon(Icons.access_time),
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                                errorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.red)),
                                focusedErrorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(
                                        color: Colors.red, width: 1.5)),
                              ),
                              onTap: () async {
                                if (isGregorian) {
                                  final DateTime? pickedDate =
                                      await showDatePicker(
                                    context: context,
                                    initialDate:
                                        DateTime.parse(selectedDate.toString()),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate != null) {
                                    final TimeOfDay? pickedTime =
                                        await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (pickedTime != null) {
                                      selectedDateTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );

                                      intl2.DateFormat formatter =
                                          intl2.DateFormat('yyyy-MM-dd HH:mm');
                                      String formattedDateTime =
                                          formatter.format(selectedDateTime);
                                      editApptTimeController.text =
                                          formattedDateTime;
                                    }
                                  }
                                } else {
                                  // Set Hijry/Jalali calendar
                                  Jalali? hijriDate =
                                      await showPersianDatePicker(
                                          context: context,
                                          initialDate: Jalali.now(),
                                          firstDate: Jalali(1395, 8),
                                          lastDate: Jalali(1450, 9));
                                  if (hijriDate != null) {
                                    final TimeOfDay? pickedTime =
                                        await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (pickedTime != null) {
                                      selectedDateTime = DateTime(
                                        hijriDate.year,
                                        hijriDate.month,
                                        hijriDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                      // Fortmat to display a more user-friendly manner in the field like: 2024-05-04 07:00
                                      final intl2.DateFormat formatter =
                                          intl2.DateFormat('yyyy-MM-dd HH:mm');
                                      String formattedDateTime =
                                          formatter.format(selectedDateTime);
                                      editApptTimeController.text =
                                          formattedDateTime;
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: TextFormField(
                              controller: editCommentController,
                              validator: (value) {
                                if (value!.isNotEmpty) {
                                  if (value.length < 5 || value.length > 40) {
                                    return translations[selectedLanguage]
                                            ?['OtherDDLLength'] ??
                                        '';
                                  }
                                  return null;
                                }
                                return null;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(GlobalUsage.allowedEPChar))
                              ],
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['RetDetails'] ??
                                    '',
                                suffixIcon:
                                    const Icon(Icons.description_outlined),
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.grey)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.blue)),
                                errorBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.red)),
                                focusedErrorBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide:
                                      BorderSide(color: Colors.red, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 10.0),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                suffixIcon:
                                    Icon(Icons.notifications_active_outlined),
                                border: OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.red),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: SizedBox(
                                  height: 26.0,
                                  child: DropdownButton(
                                    // isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    value: notifFreq,
                                    items: <String>[
                                      '5 Minutes',
                                      '15 Minutes',
                                      '30 Minutes',
                                      '1 Hour',
                                      '2 Hours'
                                    ].map<DropdownMenuItem<String>>(
                                        (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        notifFreq = newValue!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                actions: <Widget>[
                  ElevatedButton(
                    child: Text(
                        translations[selectedLanguage]?['SaveUABtn'] ?? ''),
                    onPressed: () async {
                      if (_calFormKey.currentState!.validate()) {
                        try {
                          String schedApptDT;
                          if (isGregorian) {
                            schedApptDT = editApptTimeController.text;
                          } else {
                            // First we separate date and time
                            List<String> shamsiParts =
                                editApptTimeController.text.split(' ');
                            String shamsiDate = shamsiParts[0];
                            String shamsiTime = shamsiParts[1];
                            // Now we separate year, month, day in shamsi date
                            List<String> dateParts = shamsiDate.split('-');
                            // Convert shamsi to gregorian
                            Jalali jalali = Jalali(
                                int.parse(dateParts[0]),
                                int.parse(dateParts[1]),
                                int.parse(dateParts[2]));

                            // Fetch it into Date type
                            Date gregDate = jalali.toGregorian();
                            // We need datetime type to format it
                            DateTime gregDateTime = DateTime(
                                gregDate.year, gregDate.month, gregDate.day);

                            // Format it to be in yyyy-mm-dd
                            intl2.DateFormat formatter =
                                intl2.DateFormat('yyyy-MM-dd');
                            schedApptDT =
                                '${formatter.format(gregDateTime)} $shamsiTime';
                          }
                          final conn = await onConnToSqliteDb();
                          final results = await conn.rawUpdate(
                              'UPDATE appointments SET service_ID = ?, staff_ID = ?, meet_date = ?, notification = ?, details = ? WHERE apt_ID = ?',
                              [
                                selectedServiceId,
                                selectedStaffId,
                                schedApptDT,
                                notifFreq,
                                editCommentController.text.isEmpty
                                    ? null
                                    : editCommentController.text,
                                apptId
                              ]);
                          if (results > 0) {
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop();
                            // ignore: use_build_context_synchronously
                            _onShowSnack(
                                Colors.green,
                                translations[selectedLanguage]
                                        ?['StaffEditMsg'] ??
                                    '',
                                context);
                            refresh();
                          } else {
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop();
                            // ignore: use_build_context_synchronously
                            _onShowSnack(
                                Colors.red,
                                translations[selectedLanguage]
                                        ?['StaffEditErrMsg'] ??
                                    '',
                                context);
                          }
                        } catch (e) {
                          print('Appointment scheduling failed: $e');
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// This function deletes a schedule appointment
  _onDeleteAppointment(BuildContext context, int apptId, Function refresh) {
    return showDialog(
      useRootNavigator: true,
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Directionality(
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child:
                  Text(translations[selectedLanguage]?['DeleteAHeading'] ?? ''),
            ),
            content: Directionality(
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child:
                  Text(translations[selectedLanguage]?['ConfirmDelAppt'] ?? ''),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(translations[selectedLanguage]?['CancelBtn'] ?? ''),
              ),
              TextButton(
                onPressed: () async {
                  final conn = await onConnToSqliteDb();
                  final deleteResult = await conn.rawDelete(
                      'DELETE FROM appointments WHERE apt_ID = ?', [apptId]);
                  if (deleteResult > 0) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop();
                    // ignore: use_build_context_synchronously
                    _onShowSnack(
                        Colors.green,
                        translations[selectedLanguage]?['DeleteSuccessMsg'] ??
                            '',
                        context);
                    refresh();
                  }
                },
                child: Text(translations[selectedLanguage]?['Delete'] ?? ''),
              ),
            ],
          );
        },
      ),
    );
  }

  // This function fetches the scheduled appointments from database
  Future<List<PatientAppointment>> _fetchAppointments() async {
    try {
      final conn = await onConnToSqliteDb();
      final results = await conn.rawQuery(
          '''SELECT firstname, lastname, ser_name, details, meet_date, apt_ID, notification, a.service_ID AS ser_id, a.staff_ID AS staff_id FROM staff st 
             INNER JOIN appointments a ON st.staff_ID = a.staff_ID 
             INNER JOIN services s ON a.service_ID = s.ser_ID WHERE a.status = ? AND a.pat_ID = ?''',
          ['Pending', PatientInfo.patID]);
      return results
          .map((row) => PatientAppointment(
              dentistFName: row["firstname"].toString(),
              dentistLName: row["lastname"].toString(),
              serviceName: row["ser_name"].toString(),
              comments: row["details"] == null ? '' : row["details"].toString(),
              visitTime: DateTime.parse(row["meet_date"].toString()),
              apptId: row["apt_ID"] as int,
              notifFreq: row["notification"].toString(),
              serviceID: row["ser_id"] as int,
              staffID: row["staff_id"] as int))
          .toList();
    } catch (e) {
      print('The scheduled appoinments cannot be retrieved: $e');
      return [];
    }
  }

// Dislay the scheduled appointment
  Future<AppointmentDataSource> _getCalendarDataSource() async {
    List<PatientAppointment> appointments = await _fetchAppointments();
    List<Meeting> meetings = appointments.map((appointment) {
      Color bgColor;

      switch (appointment.apptId % 5) {
        case 0:
          bgColor = Colors.red;
          break;
        case 1:
          bgColor = Colors.green;
          break;
        case 2:
          bgColor = Colors.brown;
          break;
        case 3:
          bgColor = const Color.fromARGB(255, 46, 12, 236);
          break;
        default:
          bgColor = Colors.purple;
      }

      return Meeting(
        from: appointment.visitTime,
        to: appointment.visitTime.add(const Duration(hours: 1)),
        eventName:
            'Appointment with ${appointment.dentistFName} ${appointment.dentistLName}',
        description: appointment.comments,
        patientAppointment: appointment,
        background: bgColor,
      );
    }).toList();

    return AppointmentDataSource(meetings);
  }
}

class Meeting {
  Meeting({
    required this.from,
    required this.to,
    required this.eventName,
    required this.description,
    required this.patientAppointment,
    this.background = const Color.fromARGB(255, 211, 40, 34),
  });

  DateTime from;
  DateTime to;
  String eventName;
  String description;
  PatientAppointment patientAppointment;
  Color background;
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Meeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return appointments![index].from;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].to;
  }

  @override
  String getSubject(int index) {
    return appointments![index].eventName;
  }

  @override
  Color getColor(int index) {
    return appointments![index].background;
  }

  @override
  bool isAllDay(int index) {
    return false;
  }
}

/// Custom business object class which contains properties to hold the detailed
/// information about the event data which will be rendered in calendar.
class PatientAppointment {
  final int staffID;
  final int apptId;
  final int serviceID;
  final String dentistFName;
  final String dentistLName;
  final String serviceName;
  final String comments;
  final DateTime visitTime;
  final String notifFreq;

  PatientAppointment(
      {required this.staffID,
      required this.apptId,
      required this.serviceID,
      required this.dentistFName,
      required this.dentistLName,
      required this.serviceName,
      required this.comments,
      required this.visitTime,
      required this.notifFreq});
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dentistry/config/developer_options.dart';
import 'package:flutter_dentistry/config/global_usage.dart';
import 'package:flutter_dentistry/config/language_provider.dart';
import 'package:flutter_dentistry/models/db_conn.dart';
import 'package:flutter_dentistry/views/main/dashboard.dart';
import 'package:flutter_dentistry/views/patients/new_patient.dart';
import 'package:flutter_dentistry/views/patients/patient_details.dart';
import 'package:flutter_dentistry/views/services/service_related_fields.dart';
import 'package:flutter_dentistry/views/staff/staff_info.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:win32/win32.dart';
import 'patient_info.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_dentistry/config/translations.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

void main() {
  return runApp(const Patient());
}

// Assign default selected staff
String? defaultSelectedStaff;
List<Map<String, dynamic>> staffList = [];

int? staffID;
int? patientID;
// Dentist's Profession related variables
String? dentistEducation;
String? dentistSecondPosition;

// ignore: prefer_typing_uninitialized_variables
var selectedLanguage;
// ignore: prefer_typing_uninitialized_variables
var isEnglish;

// Assign default selected staff
String? defaultSelectedPatient;
List<Map<String, dynamic>> patientsList = [];
// This dialog creates prescription
onCreatePrescription(BuildContext context) {
  // This list will contain medicine types
  List<Map<String, dynamic>> medicines = [
    {
      'type': 'Syrups',
      'piece': '150mg',
      'qty': '1',
      'dose': '1 x 1',
      'nameController': TextEditingController(),
      'descController': TextEditingController()
    }
  ];
  int counter = 0;
  // Medicine name must be only English
  const regExp4medicineName = "[a-zA-Z]";
  // Details can be in Egnlish / Persian
  const regExp4medicineDetail = "[a-zA-Z,، \u0600-\u06FFF]";
  TextEditingController patientSearchableController = TextEditingController();
  int? selectedPatientID;
  String? selectedPFName;
  String? selectedPLName;
  int? selectedPAge;
  String? selectedPSex;

  // Set 1 - 100 for medicine quantity
  List<String> medicineQty = [];
  for (int i = 1; i <= 100; i++) {
    medicineQty.add('$i');
  }
  // Set Dentist Professions
  List<String> dentistProfessions = [
    'متخصص امراض جوف دهن و دندان',
    'متخصص جراحی وجه و فک',
    'متخصص امپلنتولوجیست',
    'متخصص ارتودانسی'
  ];

  String selectedProfession = 'متخصص امراض جوف دهن و دندان';
  bool maxMedicineReached = false;

// Key for Form widget
  final formKeyPresc = GlobalKey<FormState>();
  // ignore: use_build_context_synchronously
  return showDialog(
    context: context,
    builder: ((context) {
      return StatefulBuilder(
        builder: (BuildContext context, setState) {
          return AlertDialog(
            title: Directionality(
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    translations[selectedLanguage]?['GenPrescHeading'] ?? '',
                    style: const TextStyle(color: Colors.blue),
                  ),
                  Visibility(
                    visible: maxMedicineReached ? true : false,
                    child: Text(
                      translations[selectedLanguage]?['MedItemMax'] ?? '',
                      style: const TextStyle(color: Colors.red, fontSize: 12.0),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                          child: Text(translations[selectedLanguage]
                                  ?['CancelBtn'] ??
                              '')),
                      (Features.genPrescription)
                          ? ElevatedButton(
                              onPressed: () async {
                                if (formKeyPresc.currentState!.validate()) {
                                  /* -------------------- Fetch staff firstname & lastname ---------------- */
                                  final conn = await onConnToSqliteDb();
                                  final results = await conn.rawQuery(
                                      'SELECT * FROM staff WHERE staff_ID = ?',
                                      [defaultSelectedStaff]);
                                  var row = results.first;
                                  String drFirstName =
                                      row['firstname'].toString();
                                  String drLastName =
                                      row['lastname'].toString();
                                  String drPhone = row['phone'].toString();
                                  /* --------------------/. Fetch staff firstname & lastname ---------------- */

                                  // Current date
                                  DateTime now = DateTime.now();
                                  String formattedDate =
                                      intl.DateFormat('yyyy/MM/dd').format(now);

                                  const assetImgProvider = AssetImage(
                                    'assets/graphics/logo1.png',
                                  );
                                  ImageProvider? blobImgProvider;

                                  Uint8List? firstClinicLogoBuffer =
                                      firstClinicLogo?.buffer.asUint8List();
                                  if (firstClinicLogoBuffer != null &&
                                      firstClinicLogoBuffer.isNotEmpty) {
                                    final Completer<ui.Image> completer =
                                        Completer();
                                    ui.decodeImageFromList(
                                        firstClinicLogoBuffer, (ui.Image img) {
                                      return completer.complete(img);
                                    });
                                    blobImgProvider =
                                        MemoryImage(firstClinicLogoBuffer);
                                  }

                                  final clinicLogo = await flutterImageProvider(
                                      blobImgProvider ?? assetImgProvider);
                                  final pdf = pw.Document();
                                  final fontData = await rootBundle
                                      .load('assets/fonts/per_sans_font.ttf');
                                  final ttf = pw.Font.ttf(fontData);
                                  final iconData = await rootBundle
                                      .load('assets/fonts/material-icons.ttf');
                                  final iconTtf = pw.Font.ttf(iconData);

                                  pdf.addPage(pw.Page(
                                    pageFormat: PdfPageFormat.a4,
                                    build: (pw.Context context) {
                                      return pw.Column(children: [
                                        pw.Header(
                                          level: 0,
                                          child: pw.Row(
                                              mainAxisAlignment:
                                                  pw.MainAxisAlignment.center,
                                              children: [
                                                pw.ClipOval(
                                                    child: pw.Container(
                                                  width: 50,
                                                  height: 50,
                                                  child: pw.Image(clinicLogo),
                                                )),
                                                pw.Column(children: [
                                                  pw.Text(
                                                    textDirection:
                                                        pw.TextDirection.rtl,
                                                    firstClinicName ??
                                                        'Clinic Name',
                                                    style: pw.TextStyle(
                                                      fontSize: 20,
                                                      font: ttf,
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                      color: const PdfColor(
                                                          51 / 255,
                                                          153 / 255,
                                                          255 / 255),
                                                    ),
                                                  ),
                                                  pw.Text(
                                                    textDirection:
                                                        pw.TextDirection.rtl,
                                                    'داکتر $drFirstName $drLastName',
                                                    style: pw.TextStyle(
                                                      font: ttf,
                                                      fontSize: 12,
                                                      color: const PdfColor(
                                                          51 / 255,
                                                          153 / 255,
                                                          255 / 255),
                                                    ),
                                                  ),
                                                  pw.Text(
                                                    textDirection:
                                                        pw.TextDirection.rtl,
                                                    selectedProfession,
                                                    style: pw.TextStyle(
                                                      font: ttf,
                                                      fontSize: 10,
                                                      color: const PdfColor(
                                                          51 / 255,
                                                          153 / 255,
                                                          255 / 255),
                                                    ),
                                                  ),
                                                  if (dentistEducation !=
                                                          null ||
                                                      dentistEducation != null)
                                                    pw.Text(
                                                      textDirection:
                                                          pw.TextDirection.rtl,
                                                      '$dentistEducation',
                                                      style: pw.TextStyle(
                                                        font: ttf,
                                                        fontSize: 10,
                                                        color: const PdfColor(
                                                            51 / 255,
                                                            153 / 255,
                                                            255 / 255),
                                                      ),
                                                    ),
                                                  if (dentistSecondPosition !=
                                                          null ||
                                                      dentistSecondPosition !=
                                                          null)
                                                    pw.Text(
                                                      textDirection:
                                                          pw.TextDirection.rtl,
                                                      '$dentistSecondPosition',
                                                      style: pw.TextStyle(
                                                        font: ttf,
                                                        fontSize: 10,
                                                        color: const PdfColor(
                                                            51 / 255,
                                                            153 / 255,
                                                            255 / 255),
                                                      ),
                                                    ),
                                                ]),
                                              ]),
                                        ),
                                        pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceBetween,
                                          children: <pw.Widget>[
                                            pw.Directionality(
                                                child: pw.Align(
                                                  alignment:
                                                      pw.Alignment.centerRight,
                                                  child: pw.Text(
                                                    'Patient\'s Name: $selectedPFName $selectedPLName',
                                                    style:
                                                        pw.TextStyle(font: ttf),
                                                  ),
                                                ),
                                                textDirection:
                                                    pw.TextDirection.rtl),
                                            pw.Directionality(
                                                child: pw.Align(
                                                  alignment:
                                                      pw.Alignment.centerLeft,
                                                  child: pw.Text(
                                                    'Age: $selectedPAge سال',
                                                    style:
                                                        pw.TextStyle(font: ttf),
                                                  ),
                                                ),
                                                textDirection:
                                                    pw.TextDirection.rtl),
                                            pw.Directionality(
                                                child: pw.Align(
                                                  alignment:
                                                      pw.Alignment.centerLeft,
                                                  child: pw.Text(
                                                    'Sex: $selectedPSex',
                                                    style:
                                                        pw.TextStyle(font: ttf),
                                                  ),
                                                ),
                                                textDirection:
                                                    pw.TextDirection.rtl),
                                            pw.Directionality(
                                                child: pw.Text(
                                                  'Date: $formattedDate',
                                                  style:
                                                      pw.TextStyle(font: ttf),
                                                ),
                                                textDirection:
                                                    pw.TextDirection.rtl),
                                          ],
                                        ),
                                        pw.Divider(
                                          height: 10,
                                          thickness: 1.0,
                                        ),
                                        pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Container(
                                              padding:
                                                  const pw.EdgeInsets.all(5.0),
                                              width: 60.0,
                                              child: pw.Column(
                                                crossAxisAlignment:
                                                    pw.CrossAxisAlignment.start,
                                                children: [
                                                  pw.Text('Clinical Record',
                                                      style: pw.Theme.of(
                                                              context)
                                                          .header5
                                                          .copyWith(
                                                              fontSize: 12.0,
                                                              fontWeight: pw
                                                                  .FontWeight
                                                                  .bold)),
                                                  pw.SizedBox(height: 40.0),
                                                  pw.Text('B.P'),
                                                  pw.SizedBox(height: 50.0),
                                                  pw.Text('P.R'),
                                                  pw.SizedBox(height: 50.0),
                                                  pw.Text('R.R'),
                                                  pw.SizedBox(height: 50.0),
                                                  pw.Text('P.T'),
                                                ],
                                              ),
                                            ),
                                            pw.SizedBox(
                                                child: pw.VerticalDivider(
                                                    color:
                                                        const PdfColor(0, 0, 0),
                                                    thickness: 1.0),
                                                height: 530.0),
                                            pw.Column(
                                                mainAxisAlignment:
                                                    pw.MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    pw.CrossAxisAlignment.start,
                                                children: [
                                                  pw.Padding(
                                                    padding:
                                                        const pw.EdgeInsets.all(
                                                            10),
                                                    child: pw.Text('Rx',
                                                        style:
                                                            pw.Theme.of(context)
                                                                .header1
                                                                .copyWith(
                                                                    fontSize:
                                                                        35.0)),
                                                  ),
                                                  pw.Column(
                                                      crossAxisAlignment: pw
                                                          .CrossAxisAlignment
                                                          .start,
                                                      mainAxisAlignment: pw
                                                          .MainAxisAlignment
                                                          .spaceBetween,
                                                      children: [
                                                        ...medicines
                                                            .map((medicine) {
                                                          counter++;
                                                          return pw.Padding(
                                                            padding: const pw
                                                                .EdgeInsets.only(
                                                                top: 10,
                                                                left:
                                                                    15.0), // Adjust the value as needed
                                                            child: pw.Align(
                                                              alignment: pw
                                                                  .Alignment
                                                                  .centerLeft,
                                                              child: pw.Wrap(
                                                                spacing: 15.0,
                                                                // Make each column the same width
                                                                children: [
                                                                  pw.Text(
                                                                      '$counter)'),
                                                                  pw.Text(
                                                                    (medicine['type'] ==
                                                                            'Syrups')
                                                                        ? 'SYR'
                                                                        : (medicine['type'] ==
                                                                                'Capsules')
                                                                            ? 'CAP'
                                                                            : (medicine['type'] == 'Tablets')
                                                                                ? 'TAB'
                                                                                : (medicine['type'] == 'Ointments')
                                                                                    ? 'UNG'
                                                                                    : (medicine['type'] == 'Solutions')
                                                                                        ? 'SOL'
                                                                                        : (medicine['type'] == 'Ampoules')
                                                                                            ? 'AMP'
                                                                                            : (medicine['type'] == 'Flourides')
                                                                                                ? 'FL'
                                                                                                : (medicine['type']),
                                                                    style: pw.TextStyle(
                                                                        font:
                                                                            ttf),
                                                                  ),
                                                                  pw.Text(
                                                                      (medicine[
                                                                              'nameController']
                                                                          .text),
                                                                      style: pw.TextStyle(
                                                                          font:
                                                                              ttf)),
                                                                  pw.Text(
                                                                      '${medicine['piece']}',
                                                                      style: pw.TextStyle(
                                                                          font:
                                                                              ttf)),
                                                                  pw.Text(
                                                                      '${medicine['dose']}',
                                                                      style: pw.TextStyle(
                                                                          font:
                                                                              ttf)),
                                                                  pw.Text(
                                                                      'N = ${medicine['qty']}',
                                                                      style: pw.TextStyle(
                                                                          font:
                                                                              ttf)),
                                                                  pw.Directionality(
                                                                    textDirection: pw
                                                                        .TextDirection
                                                                        .rtl,
                                                                    child:
                                                                        pw.Text(
                                                                      '${medicine['descController'].text ?? ''}',
                                                                      style: pw.TextStyle(
                                                                          font:
                                                                              ttf),
                                                                    ),
                                                                  ), // Use an empty string if the description is null
                                                                  pw.SizedBox(
                                                                      width:
                                                                          2.0)
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                        pw.SizedBox(
                                                            height: 170.0),
                                                        pw.Container(
                                                          alignment: pw
                                                              .Alignment
                                                              .bottomCenter,
                                                          margin: const pw
                                                              .EdgeInsets.only(
                                                              left: 150.0),
                                                          child: pw.Text(
                                                              'Signature:'),
                                                        )
                                                      ]),
                                                ]),
                                          ],
                                        ),
                                        pw.Divider(
                                          height: 10,
                                          thickness: 1.0,
                                        ),
                                        pw.Column(
                                            crossAxisAlignment:
                                                pw.CrossAxisAlignment.end,
                                            children: [
                                              pw.Row(
                                                  mainAxisAlignment:
                                                      pw.MainAxisAlignment.end,
                                                  children: [
                                                    pw.Text(
                                                      textDirection:
                                                          pw.TextDirection.rtl,
                                                      firstClinicAddr ??
                                                          'Clinic Address',
                                                      style: pw.TextStyle(
                                                        fontSize: 12,
                                                        font: ttf,
                                                      ),
                                                    ),
                                                    pw.SizedBox(width: 5.0),
                                                    pw.Icon(
                                                      const pw.IconData(0xE0C8),
                                                      font: iconTtf,
                                                      size: 14,
                                                    ),
                                                  ]),
                                              pw.Row(
                                                  mainAxisAlignment:
                                                      pw.MainAxisAlignment.end,
                                                  children: [
                                                    firstClinicPhone2!
                                                            .isNotEmpty
                                                        ? pw.SizedBox(
                                                            width: 180,
                                                            child: pw.Row(
                                                                mainAxisAlignment: pw
                                                                    .MainAxisAlignment
                                                                    .spaceBetween,
                                                                children: [
                                                                  pw.Text(
                                                                      textDirection: pw
                                                                          .TextDirection
                                                                          .ltr,
                                                                      firstClinicPhone1 ??
                                                                          '',
                                                                      style: pw.TextStyle(
                                                                          font:
                                                                              ttf)),
                                                                  if (firstClinicPhone2!
                                                                      .isNotEmpty)
                                                                    pw.Text(
                                                                        '-'),
                                                                  pw.Text(
                                                                      textDirection: pw
                                                                          .TextDirection
                                                                          .ltr,
                                                                      firstClinicPhone2 ??
                                                                          '',
                                                                      style: pw.TextStyle(
                                                                          font:
                                                                              ttf)),
                                                                ]),
                                                          )
                                                        : pw.Text(
                                                            textDirection: pw
                                                                .TextDirection
                                                                .ltr,
                                                            firstClinicPhone1 ??
                                                                '',
                                                            style: pw.TextStyle(
                                                                font: ttf)),
                                                    pw.SizedBox(width: 5.0),
                                                    pw.Icon(
                                                      const pw.IconData(0xE0CD),
                                                      font: iconTtf,
                                                      size: 14,
                                                    ),
                                                  ]),
                                            ]),
                                      ]);
                                    },
                                  ));

                                  // Save the PDF
                                  final bytes = await pdf.save();
                                  final fileName = selectedPFName!.isNotEmpty
                                      ? '$selectedPFName.pdf'
                                      : 'prescription.pdf';
                                  await Printing.sharePdf(
                                      bytes: bytes, filename: fileName);
                                  // ignore: use_build_context_synchronously
                                  Navigator.pop(context);
                                  /*   // Print the PDF
                            await Printing.layoutPdf(
                              onLayout: (PdfPageFormat format) async => bytes,
                            ); */
                                }
                              },
                              child: Text(translations[selectedLanguage]
                                      ?['CreatePrescBtn'] ??
                                  ''),
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
                                      ?['CreatePrescBtn'] ??
                                  ''),
                            ),
                    ],
                  ))
            ],
            content: Directionality(
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: Form(
                key: formKeyPresc,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Directionality(
                                  textDirection: isEnglish
                                      ? TextDirection.ltr
                                      : TextDirection.rtl,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width *
                                        0.16,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 10.0),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        border: const OutlineInputBorder(),
                                        labelText:
                                            translations[selectedLanguage]
                                                    ?['SelectDentist'] ??
                                                '',
                                        labelStyle: const TextStyle(
                                            color: Colors.blueAccent),
                                        enabledBorder: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(15.0)),
                                            borderSide: BorderSide(
                                                color: Colors.blueAccent)),
                                        focusedBorder: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(15.0)),
                                            borderSide:
                                                BorderSide(color: Colors.blue)),
                                        errorBorder: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(15.0)),
                                            borderSide:
                                                BorderSide(color: Colors.red)),
                                        focusedErrorBorder:
                                            const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(15.0)),
                                                borderSide: BorderSide(
                                                    color: Colors.red,
                                                    width: 1.5)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: Container(
                                          height: 18.0,
                                          padding: EdgeInsets.zero,
                                          child: DropdownButton(
                                            isExpanded: true,
                                            icon: const Icon(
                                                Icons.arrow_drop_down),
                                            value: defaultSelectedStaff,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black),
                                            items: staffList.map((staff) {
                                              return DropdownMenuItem<String>(
                                                value: staff['staff_ID'],
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(staff['firstname'] +
                                                    ' ' +
                                                    staff['lastname']),
                                              );
                                            }).toList(),
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                defaultSelectedStaff = newValue;
                                                staffID = int.parse(newValue!);
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.17,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 5.0, vertical: 10.0),
                                  child: Column(
                                    children: [
                                      Directionality(
                                        textDirection: isEnglish
                                            ? TextDirection.ltr
                                            : TextDirection.rtl,
                                        child: TypeAheadField(
                                          suggestionsCallback: (search) async {
                                            try {
                                              final conn =
                                                  await onConnToSqliteDb();
                                              var results = await conn.rawQuery(
                                                  'SELECT pat_ID, firstname, lastname, phone, age, sex FROM patients WHERE firstname LIKE ?',
                                                  ['%$search%']);

                                              // Convert the results into a list of Patient objects
                                              var suggestions = results
                                                  .map((row) => PatientDataModel(
                                                      patientId:
                                                          row["pat_ID"] as int,
                                                      patientFName:
                                                          row["firstname"]
                                                              .toString(),
                                                      patientLName:
                                                          row["lastname"] ==
                                                                  null
                                                              ? ''
                                                              : row["lastname"]
                                                                  .toString(),
                                                      patientPhone: row["phone"]
                                                          .toString(),
                                                      patientAge:
                                                          row["age"] as int,
                                                      patientGender: row["sex"]
                                                          .toString()))
                                                  .toList();
                                              return suggestions;
                                            } catch (e) {
                                              print(
                                                  'Something wrong with patient searchable dropdown: $e');
                                              return [];
                                            }
                                          },
                                          builder:
                                              (context, controller, focusNode) {
                                            patientSearchableController =
                                                controller;
                                            return TextFormField(
                                              controller: controller,
                                              focusNode: focusNode,
                                              autofocus: true,
                                              autovalidateMode:
                                                  AutovalidateMode.always,
                                              validator: (value) {
                                                if (value!.isEmpty) {
                                                  return translations[
                                                              selectedLanguage]
                                                          ?['PatNotSelected'] ??
                                                      '';
                                                }
                                                return null;
                                              },
                                              decoration: InputDecoration(
                                                border:
                                                    const OutlineInputBorder(),
                                                labelText: translations[
                                                            selectedLanguage]
                                                        ?['SelectPatient'] ??
                                                    '',
                                                labelStyle: const TextStyle(
                                                    color: Colors.blue),
                                                enabledBorder:
                                                    const OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    15.0)),
                                                        borderSide: BorderSide(
                                                            color:
                                                                Colors.blue)),
                                                focusedBorder:
                                                    const OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    15.0)),
                                                        borderSide: BorderSide(
                                                            color:
                                                                Colors.blue)),
                                                errorBorder:
                                                    const OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    15.0)),
                                                        borderSide: BorderSide(
                                                            color: Colors.red)),
                                                focusedErrorBorder:
                                                    const OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    15.0)),
                                                        borderSide: BorderSide(
                                                            color: Colors.red,
                                                            width: 1.5)),
                                              ),
                                            );
                                          },
                                          itemBuilder: (context, patient) {
                                            return ListTile(
                                              title: Text(
                                                  '${patient.patientFName} ${patient.patientLName}'),
                                              subtitle:
                                                  Text(patient.patientPhone),
                                            );
                                          },
                                          onSelected: (patient) {
                                            setState(
                                              () {
                                                patientSearchableController
                                                        .text =
                                                    '${patient.patientFName} ${patient.patientLName}';
                                                selectedPatientID =
                                                    patient.patientId;
                                                selectedPFName =
                                                    patient.patientFName;
                                                selectedPLName =
                                                    patient.patientLName;
                                                selectedPAge =
                                                    patient.patientAge;
                                                selectedPSex =
                                                    patient.patientGender;
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.31,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 10.0),
                                  child: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                        border: const OutlineInputBorder(),
                                        labelText:
                                            translations[selectedLanguage]
                                                    ?['Specs'] ??
                                                '',
                                        enabledBorder: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(10.0)),
                                            borderSide:
                                                BorderSide(color: Colors.grey)),
                                        focusedBorder: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(10.0)),
                                            borderSide:
                                                BorderSide(color: Colors.blue)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: SizedBox(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.03,
                                          child: ButtonTheme(
                                            alignedDropdown: true,
                                            child: DropdownButton(
                                              padding: EdgeInsets.zero,
                                              // isExpanded: true,
                                              icon: const Icon(
                                                  Icons.arrow_drop_down),
                                              value: selectedProfession,
                                              items: dentistProfessions.map<
                                                      DropdownMenuItem<String>>(
                                                  (String value) {
                                                return DropdownMenuItem<String>(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  value: value,
                                                  child: Text(value,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  selectedProfession =
                                                      newValue!;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: translations[selectedLanguage]
                                          ?['MoreAboutDentist'] ??
                                      '',
                                  child: InkWell(
                                    onTap: () =>
                                        onAddMoreDetailsAboutDentist(context),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.grey, width: 1.3),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(
                                          Icons.notes_rounded,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ...medicines.map((medicine) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(
                                    left: 20.0,
                                    right: 20.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: translations[selectedLanguage]
                                            ?['MedType'] ??
                                        '',
                                    enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.grey)),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(50.0)),
                                      borderSide:
                                          BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: SizedBox(
                                      height: 26.0,
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: medicine['type'],
                                        onChanged: (newValue) {
                                          setState(() {
                                            medicine['type'] = newValue;
                                          });
                                        },
                                        items: <String>[
                                          'Syrups',
                                          'Capsules',
                                          'Tablets',
                                          'Mouthwashes',
                                          'Ointments',
                                          'Gels',
                                          'Solutions',
                                          'Ampoules',
                                          'Flourides',
                                          'Sprays',
                                          'Lozenges',
                                          'Drops',
                                          'Toothpastes',
                                        ].map<DropdownMenuItem<String>>(
                                            (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(
                                    left: 20.0,
                                    right: 20.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                child: TextFormField(
                                  controller: medicine['nameController'],
                                  autovalidateMode: AutovalidateMode.always,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return translations[selectedLanguage]
                                              ?['MedNameRequired'] ??
                                          '';
                                    } else if (value.length > 20 ||
                                        value.length < 5) {
                                      return translations[selectedLanguage]
                                              ?['MedNameLength'] ??
                                          '';
                                    }
                                    return null;
                                  },
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(regExp4medicineName),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: translations[selectedLanguage]
                                            ?['MedName'] ??
                                        '',
                                    suffixIcon:
                                        const Icon(Icons.note_alt_outlined),
                                    hintText: 'مثال: Amoxiciline',
                                    enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.grey)),
                                    focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.blue)),
                                    errorBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.red)),
                                    focusedErrorBorder:
                                        const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(50.0)),
                                            borderSide: BorderSide(
                                                color: Colors.red, width: 1.5)),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(
                                    left: 20.0,
                                    right: 20.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: translations[selectedLanguage]
                                            ?['MedPiece'] ??
                                        '',
                                    enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.grey)),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(50.0)),
                                      borderSide:
                                          BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: SizedBox(
                                      height: 26.0,
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: medicine['piece'],
                                        onChanged: (newValue) {
                                          setState(() {
                                            medicine['piece'] = newValue;
                                          });
                                        },
                                        items: <String>[
                                          '15mg',
                                          '30mg',
                                          '50mg',
                                          '60mg',
                                          '75mg',
                                          '100mg',
                                          '120mg',
                                          '150mg',
                                          '200mg',
                                          '250mg',
                                          '300mg',
                                          '325mg',
                                          '400mg',
                                          '450mg',
                                          '500mg',
                                          '650mg',
                                          '800mg',
                                          '1000mg'
                                        ].map<DropdownMenuItem<String>>(
                                            (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(
                                    left: 20.0,
                                    right: 20.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: translations[selectedLanguage]
                                            ?['QtyAmount'] ??
                                        '',
                                    enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.grey)),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(50.0)),
                                      borderSide:
                                          BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: SizedBox(
                                      height: 26.0,
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: medicine['qty'],
                                        onChanged: (newValue) {
                                          setState(() {
                                            medicine['qty'] = newValue;
                                          });
                                        },
                                        items: medicineQty
                                            .map<DropdownMenuItem<String>>(
                                                (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(
                                    left: 20.0,
                                    right: 20.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: translations[selectedLanguage]
                                            ?['MedDose'] ??
                                        '',
                                    enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.grey)),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(50.0)),
                                      borderSide:
                                          BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: SizedBox(
                                      height: 26.0,
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: medicine['dose'],
                                        onChanged: (newValue) {
                                          setState(() {
                                            medicine['dose'] = newValue;
                                          });
                                        },
                                        items: <String>[
                                          '1 x 1',
                                          '1 x 2',
                                          '1 x 3'
                                        ].map<DropdownMenuItem<String>>(
                                            (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Directionality(
                                                textDirection:
                                                    TextDirection.ltr,
                                                child: Text(value)),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(
                                    left: 20.0,
                                    right: 20.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                child: TextFormField(
                                  controller: medicine['descController'],
                                  autovalidateMode: AutovalidateMode.always,
                                  validator: (value) {
                                    if (value!.isNotEmpty) {
                                      if (value.length > 25 ||
                                          value.length < 5) {
                                        return translations[selectedLanguage]
                                                ?['MedDetLength'] ??
                                            '';
                                      }
                                    }
                                    return null;
                                  },
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(regExp4medicineDetail),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: translations[selectedLanguage]
                                            ?['StaffDetail'] ??
                                        '',
                                    hintText: 'مثال: بعد از غذا میل شود',
                                    suffixIcon:
                                        const Icon(Icons.note_alt_outlined),
                                    enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.grey)),
                                    focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.blue)),
                                    errorBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50.0)),
                                        borderSide:
                                            BorderSide(color: Colors.red)),
                                    focusedErrorBorder:
                                        const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(50.0)),
                                            borderSide: BorderSide(
                                                color: Colors.red, width: 1.5)),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: translations[selectedLanguage]
                                        ?['DeleteMedi'] ??
                                    '',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: 18.0,
                                ),
                                onPressed: () {
                                  setState(() {
                                    medicines.remove(medicine);
                                  });
                                },
                              ),
                            ],
                          );
                        }),
                        const SizedBox(
                          height: 30,
                        ),
                        Tooltip(
                          message: maxMedicineReached
                              // ignore: unnecessary_string_interpolations
                              ? '${translations[selectedLanguage]?['MedItemMax'] ?? ''}'
                              : translations[selectedLanguage]?['AddMedi'] ??
                                  '',
                          child: InkWell(
                            onTap: maxMedicineReached
                                ? null
                                : () {
                                    setState(() {
                                      if (medicines.length < 10) {
                                        medicines.add({
                                          'type': 'Syrups',
                                          'piece': '150mg',
                                          'qty': '1',
                                          'dose': '1 x 1',
                                          'nameController':
                                              TextEditingController(),
                                          'descController':
                                              TextEditingController()
                                        });
                                      } else {
                                        maxMedicineReached = true;
                                      }
                                    });
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: maxMedicineReached
                                        ? Colors.grey
                                        : Colors.blue,
                                    width: 2.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.add,
                                  color: maxMedicineReached
                                      ? Colors.grey
                                      : Colors.blue,
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
            ),
          );
        },
      );
    }),
  );
}

int pdfOutputCounter = 1;
int excelOutputCounter = 1;
// This function create excel output when called.
void createExcelForPatients() async {
  final conn = await onConnToSqliteDb();

  // Query data from the database.
  var results = await conn.rawQuery(
      'SELECT firstname, lastname, age || \' سال \', sex, marital_status, phone, pat_ID, strftime("%Y-%m-%d", reg_date), blood_group, COALESCE(address, \' \') FROM patients ORDER BY reg_date DESC');

  // Create a new Excel document.
  final xls.Workbook workbook = xls.Workbook();
  final xls.Worksheet sheet = workbook.worksheets[0];

  // Define column titles.
  var columnTitles = [
    'First Name',
    'Last Name',
    'Age',
    'Sex',
    'Marital Status',
    'Phone',
    'Patient ID',
    'Registration Date',
    'Blood Group',
    'Address'
  ];

  // Write column titles to the first row.
  for (var i = 0; i < columnTitles.length; i++) {
    sheet.getRangeByIndex(1, i + 1).setText(columnTitles[i]);
  }

  // Populate the sheet with data from the database.
  var rowIndex =
      1; // Start from the second row as the first row is used for column titles.
  for (var row in results) {
    var columnValues = row.values.toList();
    for (var i = 0; i < columnValues.length; i++) {
      sheet
          .getRangeByIndex(rowIndex + 1, i + 1)
          .setText(columnValues[i].toString());
    }
    rowIndex++;
  }

  // Save the Excel file.
  final List<int> bytes = workbook.saveAsStream();

  // Get the directory to save the Excel file.
  final Directory directory = await getApplicationDocumentsDirectory();
  final String path = directory.path;
  final File file = File('$path/Patients (${excelOutputCounter++}).xlsx');

  // Write the Excel file.
  await file.writeAsBytes(bytes, flush: true);

  // Open the file
  await OpenFile.open(file.path);
}

// This function generates PDF output when called.
void createPdfForPatients() async {
  final conn = await onConnToSqliteDb();

  // Query data from the database.
  var results = await conn.rawQuery(
      'SELECT firstname, lastname, age || \' سال \', sex, marital_status, phone, pat_ID, strftime("%Y-%m-%d", reg_date), blood_group, COALESCE(address, \' \') FROM patients ORDER BY reg_date DESC');

  // Create a new PDF document.
  final pdf = pw.Document();
  final fontData = await rootBundle.load('assets/fonts/per_sans_font.ttf');
  final ttf = pw.Font.ttf(fontData);

  // Define column titles.
  var columnTitles = [
    'First Name',
    'Last Name',
    'Age',
    'Sex',
    'Marital Status',
    'Phone',
    'Patient ID',
    'Registration Date',
    'Blood Group',
    'Address'
  ];

  // Populate the PDF with data from the database.
  pdf.addPage(pw.MultiPage(
    build: (context) => [
      pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.TableHelper.fromTextArray(
          cellPadding: const pw.EdgeInsets.all(3.0),
          defaultColumnWidth: const pw.FixedColumnWidth(150.0),
          context: context,
          data: <List<String>>[
            columnTitles,
            ...results.map((row) =>
                row.values.map((item) => item?.toString() ?? '--').toList()),
          ],
          border: null, // Remove cell borders
          headerStyle:
              pw.TextStyle(font: ttf, fontSize: 10.0, wordSpacing: 3.0),
          cellStyle: pw.TextStyle(font: ttf, fontSize: 10.0),
        ),
      ),
    ],
  ));

  // Save the PDF file.
  final output = await getTemporaryDirectory();
  final file = File('${output.path}/Patients ${pdfOutputCounter++}.pdf');
  await file.writeAsBytes(await pdf.save(), flush: true);

  // Open the file
  await OpenFile.open(file.path);
}

bool containsPersian(String input) {
  final persianRegex = RegExp(r'[\u0600-\u06FF]');
  return persianRegex.hasMatch(input);
}

String reverseString(String input) {
  return input.split('').reversed.join('');
}

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

// This list to be assigned clinic info.
List<Map<String, dynamic>> clinics = [];
String? firstClinicID;
String? firstClinicName;
String? firstClinicAddr;
String? firstClinicPhone1;
String? firstClinicPhone2;
String? firstClinicEmail;
Uint8List? firstClinicLogo;

class Patient extends StatefulWidget {
  const Patient({Key? key}) : super(key: key);

  @override
  _PatientState createState() => _PatientState();
}

class _PatientState extends State<Patient> {
  final GlobalUsage _globalUsage = GlobalUsage();
  // Fetch staff which will be needed later.
  Future<void> fetchStaff() async {
    // Fetch staff for purchased by fields
    var conn = await onConnToSqliteDb();
    var results = await conn.rawQuery(
        'SELECT staff_ID, firstname, lastname FROM staff WHERE position = ?',
        ['داکتر دندان']);
    defaultSelectedStaff =
        staffList.isNotEmpty ? staffList[0]['staff_ID'] : null;
    // setState(() {
    staffList = results
        .map((result) => {
              'staff_ID': result["staff_ID"].toString(),
              'firstname': result["firstname"],
              'lastname': result["lastname"]
            })
        .toList();
    // });
  }

  // Fetch patients
  Future<void> fetchPatients() async {
    // Fetch patients for prescription
    var conn = await onConnToSqliteDb();
    var results =
        await conn.rawQuery('SELECT pat_ID, firstname, lastname FROM patients');
    defaultSelectedPatient =
        patientsList.isNotEmpty ? patientsList[0]['pat_ID'] : null;
    // setState(() {
    patientsList = results
        .map((result) => {
              'pat_ID': result["pat_ID"].toString(),
              'firstname': result["firstname"],
              'lastname': result["lastname"]
            })
        .toList();
    // });
  }

// This function fetches clinic info by instantiation
  void _retrieveClinics() async {
    clinics = await _globalUsage.retrieveClinics();
    setState(() {
      firstClinicID = clinics[0]["clinicId"];
      firstClinicName = clinics[0]["clinicName"];
      firstClinicAddr = clinics[0]["clinicAddr"];
      firstClinicPhone1 = clinics[0]["clinicPhone1"];
      firstClinicPhone2 = clinics[0]["clinicPhone2"];
      firstClinicEmail = clinics[0]["clinicEmail"];
      if (clinics[0]["clinicLogo"] is Uint8List) {
        firstClinicLogo = clinics[0]["clinicLogo"];
      } else if (clinics[0]["clinicLogo"] == null) {
        print('clinicLogo is null');
      } else {
        // Handle the case when clinicLogo is not a Uint8List
        print('clinicLogo is not a Uint8List');
      }
    }); // Call setState to trigger a rebuild of the widget with the new data.
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // Call the function to list staff in the dropdown.
    fetchStaff();
    fetchPatients();
    _retrieveClinics();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch translations keys based on the selected language.
    var languageProvider = Provider.of<LanguageProvider>(context);
    selectedLanguage = languageProvider.selectedLanguage;
    isEnglish = selectedLanguage == 'English';
    // Call the function to list staff in the dropdown.
    fetchStaff();
    fetchPatients();
    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(
            title: Text(translations[selectedLanguage]?['AllPatients'] ?? ''),
            actions: [
              Visibility(
                  visible: GlobalUsage.widgetVisible,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: IconButton(
                        tooltip: 'Dashboard',
                        splashRadius: 26.0,
                        onPressed: () => Navigator.of(context)
                            .pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) => const Dashboard()),
                                (route) => route.settings.name == 'Dashboard'),
                        icon: const Icon(Icons.home_outlined)),
                  ))
            ],
          ),
          body: const PatientDataTable()),
    );
  }
}

// This is to display an alert dialog to delete a patient
onDeletePatient(BuildContext context, Function onRefresh) {
  int? patientId = PatientInfo.patID;
  String? fName = PatientInfo.firstName;
  String? lName = PatientInfo.lastName;

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Directionality(
        textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
        child: Text(
            '${translations[selectedLanguage]?['DeletePatientTitle'] ?? ''} $fName $lName'),
      ),
      content: Directionality(
        textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
        child: Text(translations[selectedLanguage]?['ConfirmDelete'] ?? ''),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment:
                !isEnglish ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                child: Text(translations[selectedLanguage]?['CancelBtn'] ?? ''),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final conn = await onConnToSqliteDb();
                    final results = await conn.rawDelete(
                        'DELETE FROM patients WHERE pat_ID = ?', [patientId]);
                    if (results > 0) {
                      /*-------- Delete all child records -------- */
                      await conn.rawDelete(
                          'DELETE FROM fee_payments WHERE apt_ID IN (SELECT apt_ID FROM appointments WHERE pat_ID = ?)',
                          [patientId]);
                      await conn.rawDelete(
                          'DELETE FROM appointments WHERE pat_ID = ?',
                          [patientId]);
                      await conn.rawDelete(
                          'DELETE FROM retreatments WHERE pat_ID = ?',
                          [patientId]);
                      await conn.rawDelete(
                          'DELETE FROM patient_services WHERE pat_ID = ?',
                          [patientId]);
                      await conn.rawDelete(
                          'DELETE FROM patient_xrays WHERE pat_ID = ?',
                          [patientId]);
                      await conn.rawDelete(
                          'DELETE FROM condition_details WHERE pat_ID = ?',
                          [patientId]);
                      // ignore: use_build_context_synchronously
                      _onShowSnack(
                          Colors.green,
                          translations[selectedLanguage]?['DeleteSuccess'] ??
                              '',
                          context);
                      onRefresh();
                    } else {
                      // ignore: use_build_context_synchronously
                      _onShowSnack(
                          Colors.red, 'متاسفم، مریض حذف نشد.', context);
                    }
                  } catch (e) {
                    if (e is SocketException) {
                      // Handle the exception here
                      print('Failed to connect to the database: $e');
                    } else {
                      // Rethrow any other exception
                      rethrow;
                    }
                  } finally {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },
                child: Text(translations[selectedLanguage]?['Delete'] ?? ''),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// This is to display an alert dialog to other profession-related values like Education & Trainer
onAddMoreDetailsAboutDentist(BuildContext context) {
  final formKeyProf = GlobalKey<FormState>();
  TextEditingController educationController = TextEditingController();
  TextEditingController secondPostController = TextEditingController();
  bool eduPosAdded = false;
  return showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Directionality(
                textDirection:
                    isEnglish ? TextDirection.ltr : TextDirection.rtl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      translations[selectedLanguage]?['DentistEduPos'] ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall!
                          .copyWith(color: Colors.blue),
                    ),
                    Visibility(
                      visible: eduPosAdded ? true : false,
                      child: Text(
                        translations[selectedLanguage]?['DentEduPosMsg'] ?? '',
                        style: const TextStyle(
                            color: Colors.green, fontSize: 12.0),
                      ),
                    ),
                  ],
                ),
              ),
              content: Directionality(
                textDirection:
                    isEnglish ? TextDirection.ltr : TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKeyProf,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(
                                left: 20.0,
                                right: 20.0,
                                top: 10.0,
                                bottom: 10.0),
                            child: TextFormField(
                              controller: educationController,
                              validator: (value) {
                                if (value!.isNotEmpty) {
                                  if (value.length > 30 || value.length < 8) {
                                    return translations[selectedLanguage]
                                            ?['DentEduLength'] ??
                                        '';
                                  }
                                }
                                return null;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(GlobalUsage.allowedEPChar),
                                ),
                              ],
                              autovalidateMode: AutovalidateMode.always,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['DentEdu'] ??
                                    '',
                                hintText: 'مثال: تحصیلات عالی در دانشگاه',
                                suffixIcon: const Icon(Icons.school_outlined),
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
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(
                                left: 20.0,
                                right: 20.0,
                                top: 10.0,
                                bottom: 10.0),
                            child: TextFormField(
                              controller: secondPostController,
                              autovalidateMode: AutovalidateMode.always,
                              validator: (value) {
                                if (value!.isNotEmpty) {
                                  if (value.length > 40 || value.length < 10) {
                                    return translations['DentPosLength']
                                            ?['DentPos'] ??
                                        '';
                                  }
                                }
                                return null;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(GlobalUsage.allowedEPChar),
                                ),
                              ],
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: translations[selectedLanguage]
                                        ?['DentPos'] ??
                                    '',
                                hintText:
                                    'مثال: ترینر یا موظف در شفاخانه علی آباد',
                                suffixIcon: const Icon(Icons.man_3_rounded),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: !isEnglish
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Add',
                        splashRadius: 25.0,
                        icon:
                            const Icon(Icons.check_rounded, color: Colors.blue),
                        onPressed: () {
                          if (formKeyProf.currentState!.validate()) {
                            dentistEducation = educationController.text.isEmpty
                                ? ''
                                : educationController.text;
                            dentistSecondPosition =
                                secondPostController.text.isEmpty
                                    ? ''
                                    : secondPostController.text;
                            if (educationController.text.isNotEmpty ||
                                secondPostController.text.isNotEmpty) {
                              setState(() {
                                eduPosAdded = true;
                              });
                            } else {
                              setState(() {
                                eduPosAdded = false;
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 10.0),
                      IconButton(
                        tooltip: 'Close',
                        splashRadius: 25.0,
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      });
}

final _editPatFormKey = GlobalKey<FormState>();

// The text editing controllers for the TextFormFields
final _firstNameController = TextEditingController();

final _lastNameController = TextEditingController();

final _phoneController = TextEditingController();

final hireDateController = TextEditingController();

final familyPhone1Controller = TextEditingController();

final familyPhone2Controller = TextEditingController();

final salaryController = TextEditingController();

final prePaidController = TextEditingController();

final tazkiraController = TextEditingController();

final _addrController = TextEditingController();

// Radio Buttons
String _sexGroupValue = 'مرد';

// This function edits patient's personal info
onEditPatientInfo(BuildContext context, Function onRefresh) {
  _firstNameController.text = PatientInfo.firstName!;
  _lastNameController.text = PatientInfo.lastName!;
  _phoneController.text = PatientInfo.phone!;
  _addrController.text = PatientInfo.address!;
  _sexGroupValue = PatientInfo.sex!;
  PatientInfo.maritalStatusDD = PatientInfo.maritalStatus!;
  PatientInfo.ageDropDown = PatientInfo.age!;
  PatientInfo.bloodDropDown = PatientInfo.bloodGroup;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Directionality(
            textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
            child: Text(
                '${translations[selectedLanguage]?['ChgMyPInfo'] ?? ''} ${PatientInfo.firstName}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(color: Colors.blue)),
          ),
          content: Directionality(
            textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
            child: SingleChildScrollView(
              child: Form(
                key: _editPatFormKey,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.35,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: TextFormField(
                            controller: _firstNameController,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return translations[selectedLanguage]
                                        ?['FNRequired'] ??
                                    '';
                              } else if (value.length < 3 ||
                                  value.length > 10) {
                                return translations[selectedLanguage]
                                        ?['FNLength'] ??
                                    '';
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: translations[selectedLanguage]
                                      ?['FName'] ??
                                  '',
                              suffixIcon:
                                  const Icon(Icons.person_add_alt_outlined),
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
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: TextFormField(
                            controller: _lastNameController,
                            validator: (value) {
                              if (value!.isNotEmpty) {
                                if (value.length < 3 || value.length > 10) {
                                  return translations[selectedLanguage]
                                          ?['LNLength'] ??
                                      '';
                                } else {
                                  return null;
                                }
                              } else {
                                return null;
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: translations[selectedLanguage]
                                      ?['LName'] ??
                                  '',
                              suffixIcon: const Icon(Icons.person),
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
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText:
                                  translations[selectedLanguage]?['Age'] ?? '',
                              enabledBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.grey)),
                              focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(50.0)),
                                  borderSide: BorderSide(color: Colors.blue)),
                              errorText: PatientInfo.ageDropDown == 0 &&
                                      !PatientInfo.ageSelected
                                  ? '${translations[selectedLanguage]?['SelectAge'].toString() ?? ''}'
                                  : null,
                              errorBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(50.0),
                                ),
                                borderSide: BorderSide(
                                    color: !PatientInfo.ageSelected
                                        ? Colors.red
                                        : Colors.grey),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: SizedBox(
                                height: 26.0,
                                child: DropdownButton(
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  value: PatientInfo.ageDropDown,
                                  items: <DropdownMenuItem<int>>[
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text(translations[selectedLanguage]
                                              ?['NoAge'] ??
                                          ''),
                                    ),
                                    ...PatientInfo.getAges()
                                        .map((int ageItems) {
                                      return DropdownMenuItem(
                                        alignment: Alignment.centerRight,
                                        value: ageItems,
                                        child: Directionality(
                                          textDirection: isEnglish
                                              ? TextDirection.ltr
                                              : TextDirection.rtl,
                                          child: Text(
                                              '$ageItems ${translations[selectedLanguage]?['Year'] ?? ''}'),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (int? newValue) {
                                    if (newValue != 0) {
                                      // Ignore the 'Please select an age' option
                                      setState(() {
                                        PatientInfo.ageDropDown = newValue!;
                                        PatientInfo.ageSelected = true;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: TextFormField(
                            textDirection: TextDirection.ltr,
                            controller: _phoneController,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(GlobalUsage.allowedDigits),
                              ),
                            ],
                            validator: (value) {
                              if (value!.isEmpty) {
                                return translations[selectedLanguage]
                                        ?['PhoneRequired'] ??
                                    '';
                              } else if (value.startsWith('07')) {
                                if (value.length < 10 || value.length > 10) {
                                  return translations[selectedLanguage]
                                          ?['Phone10'] ??
                                      '';
                                }
                              } else if (value.startsWith('+93')) {
                                if (value.length < 12 || value.length > 12) {
                                  return translations[selectedLanguage]
                                          ?['Phone12'] ??
                                      '';
                                }
                              } else {
                                return translations[selectedLanguage]
                                        ?['ValidPhone'] ??
                                    '';
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: translations[selectedLanguage]
                                      ?['Phone'] ??
                                  '',
                              suffixIcon: const Icon(Icons.phone),
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
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: TextFormField(
                            controller: _addrController,
                            validator: (value) {
                              if (value!.isNotEmpty) {
                                if (value.length > 40 || value.length < 5) {
                                  return translations[selectedLanguage]
                                          ?['َAddrLength'] ??
                                      '';
                                }
                                return null;
                              }
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(GlobalUsage.allowedEPChar),
                              ),
                            ],
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: translations[selectedLanguage]
                                      ?['Address'] ??
                                  '',
                              suffixIcon:
                                  const Icon(Icons.location_on_outlined),
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
                                borderSide: BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 10.0),
                              border: const OutlineInputBorder(),
                              labelText: translations[selectedLanguage]?['Sex'],
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(50.0),
                                ),
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(50.0),
                                ),
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      listTileTheme: const ListTileThemeData(
                                          horizontalTitleGap: 0.5),
                                    ),
                                    child: RadioListTile(
                                        title: Text(
                                          translations[selectedLanguage]
                                                  ?['Male'] ??
                                              '',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        value: 'مرد',
                                        groupValue: _sexGroupValue,
                                        onChanged: (String? value) {
                                          setState(() {
                                            _sexGroupValue = value!;
                                          });
                                        }),
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      listTileTheme: const ListTileThemeData(
                                          horizontalTitleGap: 0.5),
                                    ),
                                    child: RadioListTile(
                                        title: Text(
                                          translations[selectedLanguage]
                                                  ?['Female'] ??
                                              '',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        value: 'زن',
                                        groupValue: _sexGroupValue,
                                        onChanged: (String? value) {
                                          setState(() {
                                            _sexGroupValue = value!;
                                          });
                                        }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: translations[selectedLanguage]
                                  ?['Marital'],
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
                                  value: PatientInfo.maritalStatusDD,
                                  items: PatientInfo.items.map((String items) {
                                    return DropdownMenuItem<String>(
                                      alignment: Alignment.centerRight,
                                      value: items,
                                      child: Text(items),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      PatientInfo.maritalStatusDD = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                              left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
                          child: Column(
                            children: <Widget>[
                              InputDecorator(
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText: translations[selectedLanguage]
                                      ?['BloodGroup'],
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(50.0)),
                                    borderSide: BorderSide(color: Colors.blue),
                                  ),
                                  errorBorder: const OutlineInputBorder(
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
                                      value: PatientInfo.bloodDropDown,
                                      items: PatientInfo.bloodGroupItems
                                          .map((String bloodGroupItems) {
                                        return DropdownMenuItem(
                                          alignment: Alignment.centerRight,
                                          value: bloodGroupItems,
                                          child: Text(bloodGroupItems),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          PatientInfo.bloodDropDown = newValue;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            Directionality(
              textDirection: isEnglish ? TextDirection.rtl : TextDirection.ltr,
              child: Row(
                children: [
                  TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: Text(
                          translations[selectedLanguage]?['CancelBtn'] ?? '')),
                  ElevatedButton(
                      onPressed: () async {
                        try {
                          if (_editPatFormKey.currentState!.validate()) {
                            final conn = await onConnToSqliteDb();
                            String firstName = _firstNameController.text;
                            String? lastName = _lastNameController.text.isEmpty
                                ? null
                                : _lastNameController.text;
                            int selectedAge = PatientInfo.ageDropDown;
                            String selectedSex = _sexGroupValue;
                            String marital = PatientInfo.maritalStatusDD;
                            String phone = _phoneController.text;
                            String bloodGroup = PatientInfo.bloodDropDown!;
                            String? address = _addrController.text.isEmpty
                                ? null
                                : _addrController.text;
                            final results = await conn.rawUpdate(
                                'UPDATE patients SET firstname = ?, lastname = ?, age = ?, sex = ?, marital_status = ?, phone = ?, blood_group = ?, address = ? WHERE pat_ID = ?',
                                [
                                  firstName,
                                  lastName,
                                  selectedAge,
                                  selectedSex,
                                  marital,
                                  phone,
                                  bloodGroup,
                                  address,
                                  PatientInfo.patID
                                ]);
                            if (results > 0) {
                              // ignore: use_build_context_synchronously
                              Navigator.of(context, rootNavigator: true).pop();
                              // ignore: use_build_context_synchronously
                              _onShowSnack(
                                  Colors.green,
                                  translations[selectedLanguage]
                                          ?['StaffEditMsg'] ??
                                      '',
                                  context);
                              onRefresh();
                            } else {
                              Navigator.of(context, rootNavigator: true).pop();
                              // ignore: use_build_context_synchronously
                              _onShowSnack(
                                  Colors.red,
                                  translations[selectedLanguage]
                                          ?['StaffEditErrMsg'] ??
                                      '',
                                  context);
                            }
                          }
                        } catch (e) {
                          print('Editing patient\' info failed: $e');
                        }
                      },
                      child:
                          Text(translations[selectedLanguage]?['Edit'] ?? '')),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

// Data table widget is here
class PatientDataTable extends StatefulWidget {
  const PatientDataTable({Key? key}) : super(key: key);

  @override
  _PatientDataTableState createState() => _PatientDataTableState();
}

class _PatientDataTableState extends State<PatientDataTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
// The filtered data source
  List<PatientData> _filteredData = [];

  List<PatientData> _data = [];

  Future<void> _fetchData() async {
    final conn = await onConnToSqliteDb();
    final queryResult = await conn.rawQuery(
        'SELECT firstname, lastname, age, sex, marital_status, phone, pat_ID, strftime("%Y-%m-%d", reg_date) as reg_date, blood_group, address FROM patients ORDER BY reg_date DESC');

    _data = queryResult.map((row) {
      return PatientData(
        firstName: row["firstname"].toString(),
        lastName: row["lastname"] == null ? '' : row["lastname"].toString(),
        age: row["age"].toString(),
        sex: row["sex"].toString(),
        maritalStatus: row["marital_status"].toString(),
        phone: row["phone"].toString(),
        patID: row["pat_ID"] as int,
        regDate: row["reg_date"].toString(),
        bloodGroup:
            row["blood_group"] == null ? '' : row["blood_group"].toString(),
        address: row["address"] == null ? '' : row["address"].toString(),
        patientDetail: const Icon(Icons.list),
        editPatient: const Icon(Icons.edit_outlined),
        deletePatient: const Icon(Icons.delete),
      );
    }).toList();
    _filteredData = List.from(_data);
    // Notify the framework that the state of the widget has changed
    setState(() {});
    // Print the data that was fetched from the database
    print('Data from database: $_data');
  }

// The text editing controller for the search TextField
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
// Set the filtered data to the original data at first
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

// Create instance of this class to its members
  final GlobalUsage _gu = GlobalUsage();

  @override
  Widget build(BuildContext context) {
    // Create a new instance of the PatientDataSource class and pass it the _filteredData list
    final dataSource = PatientDataSource(_filteredData, _fetchData);

    return Scaffold(
        body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 400.0,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: translations[selectedLanguage]?['Search'] ?? '',
                    suffixIcon: IconButton(
                      splashRadius: 25.0,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _filteredData = _data;
                        });
                      },
                    ),
                    enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(50.0)),
                        borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(50.0)),
                        borderSide: BorderSide(color: Colors.blue)),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filteredData = _data
                          .where((element) => element.firstName
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                          .toList();
                    });
                  },
                ),
              ),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  side: const BorderSide(
                    color: Colors.blue,
                  ),
                ),
                onPressed: () async {
                  onCreatePrescription(context);
                },
                child: Text(translations[selectedLanguage]?['GenPresc'] ?? ''),
              ),

              // Set access role to only allow 'system admin' to make such changes
              if (StaffInfo.staffRole == 'مدیر سیستم' ||
                  StaffInfo.staffRole == 'Software Engineer')
                ElevatedButton(
                  onPressed: () async {
                    if (await Features.patientLimitReached()) {
                      // ignore: use_build_context_synchronously
                      _onShowSnack(
                          Colors.red,
                          translations[selectedLanguage]?['RecordLimitMsg'] ??
                              '',
                          context);
                    } else {
                      // ignore: use_build_context_synchronously
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const NewPatient()))
                          .then((_) {
                        _fetchData();
                      });
                      // This is assigned to identify appointments.round i.e., if it is true round is stored '1' otherwise increamented by 1
                      GlobalUsage.newPatientCreated = true;
                    }
                  },
                  child: Text(
                      translations[selectedLanguage]?['AddNewPatient'] ?? ''),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${translations[selectedLanguage]?['AllPatients'] ?? ''} | ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(
                width: 80.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tooltip(
                      message: 'Excel',
                      child: InkWell(
                        onTap: createExcelForPatients,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2.0),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Icon(
                              FontAwesomeIcons.fileExcel,
                              color: Colors.blue,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'PDF',
                      child: InkWell(
                        onTap: createPdfForPatients,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2.0),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Icon(
                              FontAwesomeIcons.filePdf,
                              color: Colors.blue,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (_filteredData.isEmpty)
                const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(child: Text('هیچ مریضی یافت نشد.')),
                )
              else
                PaginatedDataTable(
                  sortAscending: _sortAscending,
                  sortColumnIndex: _sortColumnIndex,
                  header: null,
                  columns: [
                    DataColumn(
                      label: Text(
                        translations[selectedLanguage]?['FName'] ?? '',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                          _filteredData.sort(
                              (a, b) => a.firstName.compareTo(b.firstName));
                          if (!ascending) {
                            _filteredData = _filteredData.reversed.toList();
                          }
                        });
                      },
                    ),
                    DataColumn(
                      label: Text(
                        translations[selectedLanguage]?['LName'] ?? '',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                          _filteredData.sort(
                              ((a, b) => a.lastName.compareTo(b.lastName)));
                          if (!ascending) {
                            _filteredData = _filteredData.reversed.toList();
                          }
                        });
                      },
                    ),
                    DataColumn(
                      label: Text(
                        translations[selectedLanguage]?['Age'] ?? '',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                          _filteredData
                              .sort(((a, b) => a.age.compareTo(b.age)));
                          if (!ascending) {
                            _filteredData = _filteredData.reversed.toList();
                          }
                        });
                      },
                    ),
                    DataColumn(
                      label: Text(
                        translations[selectedLanguage]?['Sex'] ?? '',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                          _filteredData
                              .sort(((a, b) => a.sex.compareTo(b.sex)));
                          if (!ascending) {
                            _filteredData = _filteredData.reversed.toList();
                          }
                        });
                      },
                    ),
                    DataColumn(
                      label: Text(
                        translations[selectedLanguage]?['Marital'] ?? '',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                          _filteredData.sort(((a, b) =>
                              a.maritalStatus.compareTo(b.maritalStatus)));
                          if (!ascending) {
                            _filteredData = _filteredData.reversed.toList();
                          }
                        });
                      },
                    ),
                    DataColumn(
                      label: Text(
                        translations[selectedLanguage]?['Phone'] ?? '',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                          _filteredData
                              .sort(((a, b) => a.phone.compareTo(b.phone)));
                          if (!ascending) {
                            _filteredData = _filteredData.reversed.toList();
                          }
                        });
                      },
                    ),
                    DataColumn(
                      label: Text(
                        translations[selectedLanguage]?['Details'] ?? '',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Set access role to only allow 'system admin' to make such changes
                    if (StaffInfo.staffRole == 'مدیر سیستم' ||
                        StaffInfo.staffRole == 'Software Engineer')
                      DataColumn(
                        label: Text(
                            translations[selectedLanguage]?['Edit'] ?? '',
                            style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    if (StaffInfo.staffRole == 'مدیر سیستم' ||
                        StaffInfo.staffRole == 'Software Engineer')
                      DataColumn(
                        label: Text(
                            translations[selectedLanguage]?['Delete'] ?? '',
                            style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                  source: dataSource,
                  rowsPerPage: _filteredData.length < 8
                      ? _gu.calculateRowsPerPage(context)
                      : _gu.calculateRowsPerPage(context),
                )
            ],
          ),
        ),
      ],
    ));
  }
}

class PatientDataSource extends DataTableSource {
  List<PatientData> data;
  Function onRefresh;
  PatientDataSource(this.data, this.onRefresh);

  void sort(Comparator<PatientData> compare, bool ascending) {
    data.sort(compare);
    if (!ascending) {
      data = data.reversed.toList();
    }
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    return DataRow(cells: [
      DataCell(Text(data[index].firstName)),
      DataCell(Text(data[index].lastName)),
      DataCell(Text(
          '${data[index].age} ${translations[selectedLanguage]?['Year'] ?? ''}')),
      DataCell(Text(data[index].sex)),
      DataCell(Text(data[index].maritalStatus)),
      DataCell(Text(data[index].phone)),
      // DataCell(Text(data[index].service)),
      DataCell(
        Builder(builder: (BuildContext context) {
          return IconButton(
            splashRadius: 25.0,
            icon: data[index].patientDetail,
            onPressed: (() {
              PatientInfo.patID = data[index].patID;
              PatientInfo.firstName = data[index].firstName;
              PatientInfo.lastName = data[index].lastName;
              PatientInfo.phone = data[index].phone;
              PatientInfo.sex = data[index].sex;
              // Set age which is used to display patient details
              PatientInfo.age = int.parse(data[index].age);
              // Set age which is used when a new appointment is create for an existing patient
              ServiceInfo.patAge = int.parse(data[index].age);
              PatientInfo.regDate = data[index].regDate;
              PatientInfo.bloodGroup = data[index].bloodGroup;
              PatientInfo.address = data[index].address;
              PatientInfo.maritalStatus = data[index].maritalStatus;
              Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: ((context) => const PatientDetail())))
                  .then((_) => onRefresh());
            }),
            color: Colors.blue,
            iconSize: 20.0,
          );
        }),
      ),
      // Set access role to only allow 'system admin' to make such changes
      if (StaffInfo.staffRole == 'مدیر سیستم' ||
          StaffInfo.staffRole == 'Software Engineer')
        DataCell(
          Builder(
            builder: (BuildContext context) {
              return IconButton(
                splashRadius: 25.0,
                icon: data[index].editPatient,
                onPressed: () {
                  // Assign these values to static members of this class to be used later
                  PatientInfo.patID = data[index].patID;
                  PatientInfo.firstName = data[index].firstName;
                  PatientInfo.lastName = data[index].lastName;
                  PatientInfo.phone = data[index].phone;
                  PatientInfo.sex = data[index].sex;
                  PatientInfo.age = int.parse(data[index].age);
                  PatientInfo.regDate = data[index].regDate;
                  PatientInfo.bloodGroup = data[index].bloodGroup;
                  PatientInfo.address = data[index].address;
                  PatientInfo.maritalStatus = data[index].maritalStatus;
                  onEditPatientInfo(context, onRefresh);
                },
                color: Colors.blue,
                iconSize: 20.0,
              );
            },
          ),
        ),
      // Set access role to only allow 'system admin' to make such changes
      if (StaffInfo.staffRole == 'مدیر سیستم' ||
          StaffInfo.staffRole == 'Software Engineer')
        DataCell(
          Builder(
            builder: (BuildContext context) {
              return IconButton(
                splashRadius: 25.0,
                icon: data[index].deletePatient,
                onPressed: (() {
                  PatientInfo.patID = data[index].patID;
                  PatientInfo.firstName = data[index].firstName;
                  PatientInfo.lastName = data[index].lastName;
                  onDeletePatient(context, onRefresh);
                }),
                color: Colors.blue,
                iconSize: 20.0,
              );
            },
          ),
        ),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}

class PatientData {
  final String firstName;
  final String lastName;
  final String age;
  final String sex;
  final String maritalStatus;
  final String phone;
  final int patID;
  final String regDate;
  final String bloodGroup;
  final String address;
  // final String service;
  final Icon patientDetail;
  final Icon editPatient;
  final Icon deletePatient;

  PatientData({
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.sex,
    required this.maritalStatus,
    required this.phone,
    required this.patID,
    required this.regDate,
    required this.bloodGroup,
    required this.address,
    /* this.service, */
    required this.patientDetail,
    required this.editPatient,
    required this.deletePatient,
  });
}

// Create this data model which is required for searchable dropdown of patients
class PatientDataModel {
  final int patientId;
  final String patientFName;
  final String patientLName;
  final String patientPhone;
  final int patientAge;
  final String patientGender;

  PatientDataModel({
    required this.patientId,
    required this.patientFName,
    required this.patientLName,
    required this.patientPhone,
    required this.patientAge,
    required this.patientGender,
  });
}

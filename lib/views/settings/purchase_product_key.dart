// ignore_for_file: use_build_context_synchronously
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dentistry/config/developer_options.dart';
import 'package:flutter_dentistry/config/global_usage.dart';
import 'package:flutter_dentistry/config/language_provider.dart';
import 'package:flutter_dentistry/config/private/private.dart';
import 'package:flutter_dentistry/config/settings_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This variable is used for crown version.
bool isProVersionActivated = false;
void main() => runApp(const PurchaseProductKey());
// This is shows snackbar when called
void _onShowSnack(Color backColor, String msg, BuildContext context) {
  Flushbar(
    backgroundColor: backColor,
    flushbarStyle: FlushbarStyle.GROUNDED,
    flushbarPosition: FlushbarPosition.BOTTOM,
    messageText: Text(
      msg,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
    ),
    duration: const Duration(seconds: 3),
  ).show(context);
}

// ignore: prefer_typing_uninitialized_variables
var selectedLanguage;
// ignore: prefer_typing_uninitialized_variables
var isEnglish;

class PurchaseProductKey extends StatefulWidget {
  const PurchaseProductKey({Key? key}) : super(key: key);

  @override
  State<PurchaseProductKey> createState() => _PurchaseProductKeyState();
}

class _PurchaseProductKeyState extends State<PurchaseProductKey> {
  // form controllers
  final TextEditingController _machineCodeController = TextEditingController();
  final TextEditingController _liscenseController = TextEditingController();
  bool _isCoppied = false;
  bool _notVerified = false;
  String _verifyMsg = '';
  // form controllers
  final _licenseKey4CrownPro = GlobalKey<FormState>();
  final GlobalUsage _globalUsage = GlobalUsage();

  @override
  void initState() {
    super.initState();
    _machineCodeController.text = _globalUsage.getMachineGuid();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch translations keys based on the selected language.
    var languageProvider = Provider.of<LanguageProvider>(context);
    selectedLanguage = languageProvider.selectedLanguage;
    isEnglish = selectedLanguage == 'English';
    // Fetch crown version (Standard / PRO) from provider
    var crownVerProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    isProVersionActivated = crownVerProvider.getSelectedVersion;
    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase Your Product Key'),
      ),
      body: Center(
        child: Form(
          key: _licenseKey4CrownPro,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.vpn_key_outlined,
                      size: MediaQuery.of(context).size.width * 0.03,
                      color: Colors.blue),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    'License Key Verification',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(color: Colors.blue),
                  ),
                  const SizedBox(height: 10.0),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Text(_globalUsage.productKeyRelatedMsg,
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                  const SizedBox(height: 50.0),
                  Container(
                    margin: const EdgeInsets.all(10.0),
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: Builder(builder: (context) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Machine Code',
                              style: Theme.of(context).textTheme.labelLarge),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                TextFormField(
                                  readOnly: true,
                                  textDirection: TextDirection.ltr,
                                  controller: _machineCodeController,
                                  decoration: InputDecoration(
                                    suffixIcon: IconButton(
                                      tooltip: 'Copy',
                                      splashRadius: 18.0,
                                      onPressed: _machineCodeController
                                              .text.isEmpty
                                          ? null
                                          : () async {
                                              await Clipboard.setData(
                                                ClipboardData(
                                                    text: _machineCodeController
                                                        .text),
                                              );

                                              setState(() {
                                                _isCoppied = true;
                                              });

                                              /*   ClipboardData?
                                                                      clipboardData =
                                                                      await Clipboard
                                                                          .getData(
                                                                              Clipboard
                                                                                  .kTextPlain);
                                                                  String?
                                                                      copiedText =
                                                                      clipboardData
                                                                          ?.text;
                                                                  print(
                                                                      'The copy value: $copiedText'); */
                                            },
                                      icon: const Icon(Icons.copy, size: 15.0),
                                    ),
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.blue),
                                    ),
                                    contentPadding: const EdgeInsets.all(15.0),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                if (_isCoppied)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 5.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(
                                            Icons.check_circle_outline_outlined,
                                            color: Colors.green,
                                            size: 16.0),
                                        SizedBox(width: 5.0),
                                        Text(
                                          'Copied',
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.0),
                                        ),
                                      ],
                                    ),
                                  )
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  Container(
                    margin: const EdgeInsets.all(10.0),
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: Builder(
                      builder: (context) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Product Key',
                                style: Theme.of(context).textTheme.labelLarge),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.5,
                              child: Column(
                                children: [
                                  TextFormField(
                                    textDirection: TextDirection.ltr,
                                    controller: _liscenseController,
                                    validator: (value) {
                                      if (value!.isEmpty) {
                                        return 'Enter the product key.';
                                      }
                                      return null;
                                    },

                                    /*  inputFormatters: [
                                                                          FilteringTextInputFormatter.allow(
                                                                            RegExp(_regExUName),
                                                                          ),
                                                                        ], */
                                    decoration: const InputDecoration(
                                      enabledBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.grey),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.blue),
                                      ),
                                      contentPadding: EdgeInsets.all(15.0),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  if (_notVerified)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline,
                                              color: Colors.red, size: 17.0),
                                          const SizedBox(width: 5.0),
                                          Text(
                                            _verifyMsg,
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Builder(
                        builder: (context) {
                          return ElevatedButton.icon(
                              onPressed: () async {
                                if (_licenseKey4CrownPro.currentState!
                                    .validate()) {
                                  try {
                                    // Instantiate the shared preferences
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    // Decrypt the liscense key
                                    String decryptedValue =
                                        _globalUsage.decryptProductKey(
                                            _liscenseController.text,
                                            secretKey);

                                    // Expiry date is string
                                    String expiryDateString =
                                        decryptedValue.substring(
                                            _machineCodeController.text.length);
                                    // Convert this string to datetime
                                    DateTime expiryDate =
                                        DateTime.parse(expiryDateString);

                                    // Now re-encrypt the machine code with the fetched datetime (expiry datetime) to use for verification in below.
                                    String reEncryptedValue =
                                        _globalUsage.generateProductKey(
                                            expiryDate,
                                            _machineCodeController.text);

                                    // Store the expiry date temporarely which will be required later
                                    await _globalUsage
                                        .storeExpiryDate(expiryDate);
                                    if (reEncryptedValue ==
                                        _liscenseController.text) {
                                      if (await _globalUsage
                                          .hasLicenseKeyExpired()) {
                                        setState(() {
                                          _notVerified = true;
                                          _verifyMsg =
                                              'Sorry, this product key has expired. Please purchase the new one.';
                                        });
                                      } else {
                                        await _globalUsage
                                            .storeExpiryDate(expiryDate);
                                        await _globalUsage.storeLicenseKey4User(
                                            _liscenseController.text);
                                        Provider.of<SettingsProvider>(context,
                                                listen: false)
                                            .setSelectedVersion = true;
                                        isProVersionActivated = true;
                                        prefs.setString('crownType', 'Premium');
                                        Features.setVersion(
                                            await _globalUsage.getCrownType());
                                        // Why is it duplicated? Since it causes to exit the 'Settings' as expected.
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                        _onShowSnack(
                                            Colors.green,
                                            'Congratulations, your product key updated!',
                                            context);
                                      }
                                    } else {
                                      setState(() {
                                        _notVerified = false;
                                        _verifyMsg =
                                            'Sorry, this product key is not valid!';
                                      });
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _notVerified = true;
                                      _verifyMsg =
                                          'Sorry, invalid product key inserted.';
                                    });
                                    print('Exception: $e');
                                  }
                                }
                              },
                              icon: const Icon(Icons.verified),
                              label: const Text('Verify'));
                        },
                      ),
                      Builder(
                        builder: (context) {
                          return TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('لغو'));
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: Row(
                      children: [
                        Icon(FontAwesomeIcons.whatsapp,
                            color: Colors.grey[600]),
                        const SizedBox(width: 8.0),
                        Text('(+93)79 21 95 121',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge!
                                .copyWith(
                                    color: const Color.fromARGB(
                                        255, 116, 115, 115)))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

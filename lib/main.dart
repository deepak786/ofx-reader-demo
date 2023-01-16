import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_json_viewer/flutter_json_viewer.dart';
import 'package:xml/xml_events.dart';
import 'package:xml2json/xml2json.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  dynamic json;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          // pick ofx file
          Center(
            child: TextButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['ofx'],
                );
                if (result != null) {
                  final file = result.files.first;
                  final bytes = file.bytes;
                  debugPrint(file.name);
                  if (bytes != null) {
                    try {
                      var data = utf8.decode(bytes, allowMalformed: true);

                      // the logic to read the OFX file is referenced from the
                      // https://github.com/chilts/node-ofx
                      var ofx = data.split("<OFX>");

                      // firstly, parse the headers
                      var headerString = ofx[0].trim();
                      var headers = headerString.split(RegExp(r"\r?\n"));

                      // append the ofx tag as string is split from here
                      var ofxString = "<OFX>${ofx[1]}".trim();
                      ofxString = ofxString
                          // remove whitespace in between tag close/open
                          .replaceAll(RegExp(r">\s+<"), '><')
                          // remove whitespace before a close tag
                          .replaceAll(RegExp(r"\s+<"), '<')
                          // remove whitespace after a close tag
                          .replaceAll(RegExp(r">\s+"), '>');

                      // TODO: Some tags contain the dots (.). Do we need to remove the dots?
                      // <ORIGIN.ID>FMPWeb
                      // <INTU.BID>3101
                      // <START.TIME>20130921174852
                      // <INTU.USERID>nathanaeljones

                      // parse the string as xml events to add the missing closing nodes
                      // TODO: this can be improved
                      bool isLastTextNode = false;
                      StringBuffer ofxBuffer = StringBuffer();
                      parseEvents(ofxString, withParent: true).map((event) {
                        return {
                          "event": event.toString(),
                          "type": event.nodeType,
                          "parent": event.parent?.name
                        };
                      }).forEach(
                        (element) {
                          final event = element['event'];
                          final type = element['type'];
                          final parent = element['parent'];

                          if (type == XmlNodeType.ELEMENT) {
                            // check if the last node was text or not
                            if (isLastTextNode) {
                              final parentElement = "</$parent>";
                              if (!event.toString().startsWith(parentElement)) {
                                // the last node was text but current is not the closing
                                // tag of the previous node
                                ofxBuffer.write(parentElement);
                              }
                            }
                          }
                          ofxBuffer.write(event);
                          isLastTextNode = type == XmlNodeType.TEXT;
                        },
                      );

                      debugPrint("OFX String is >>>>>> ");
                      debugPrint(ofxString);
                      debugPrint(
                          "OFX String after manipulating for closing tags is >>>>>> ");
                      debugPrint(ofxBuffer.toString());

                      // convert the ofxString to json
                      final myTransformer = Xml2Json();
                      myTransformer.parse(ofxBuffer.toString());
                      json = jsonDecode(myTransformer.toParker());

                      // In OFX version 1.x, the headers are without any xml tag. They are just like as "header":"value".
                      // TODO: But in OFX version 2.x, they are the attributes of xml tag "<?OFX>". So need to handle that.
                      // currently everything outside the "<OFX>" tag is considered as header.
                      json['headers'] = headers;

                      setState(() {});
                    } catch (e) {
                      debugPrint("Error parsing XML file >>>> $e");
                      if (!mounted) return;

                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                }
              },
              child: const Text("Pick OFX file"),
            ),
          ),

          // display the json
          if (json != null)
            Expanded(
              child: SingleChildScrollView(child: JsonViewer(json)),
            ),
        ],
      ),
    );
  }
}

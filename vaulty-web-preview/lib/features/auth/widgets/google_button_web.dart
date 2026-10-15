import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

// Google controls the branding of this sign-in button; it is the approved theme exception.
Widget googleSdkButton() => google_web.renderButton();

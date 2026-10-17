import 'package:solar_icons/solar_icons.dart';

/// Centralized icon registry using Solar Icons with smoother curves and softer shapes.
abstract final class AppIcons {
  // Navigation
  static const home = SolarIconsOutline.home;
  static const homeActive = SolarIconsBold.home;
  static const documents = SolarIconsOutline.folder;
  static const documentsActive = SolarIconsBold.folder;
  static const upload = SolarIconsOutline.addCircle;
  static const uploadActive = SolarIconsBold.addCircle;
  static const settings = SolarIconsOutline.tuning;
  static const settingsActive = SolarIconsBold.settings;

  // Actions
  static const search = SolarIconsOutline.roundedMagnifier;
  static const searchOff = SolarIconsOutline.minimalisticMagnifierBug;
  static const refresh = SolarIconsOutline.restart;
  static const sort = SolarIconsOutline.sortFromTopToBottom;
  static const grid = SolarIconsOutline.widget_2;
  static const list = SolarIconsOutline.list;
  static const share = SolarIconsOutline.shareCircle;
  static const trash = SolarIconsOutline.trashBinTrash;
  static const edit = SolarIconsOutline.penNewSquare;
  static const add = SolarIconsOutline.addCircle;
  static const close = SolarIconsOutline.closeCircle;
  static const check = SolarIconsOutline.checkCircle;
  static const checkSquare = SolarIconsOutline.checkSquare;
  static const back = SolarIconsOutline.altArrowLeft;
  static const forward = SolarIconsOutline.altArrowRight;
  static const chevronRight = SolarIconsOutline.altArrowRight;
  static const chevronDown = SolarIconsOutline.altArrowDown;
  static const openInNew = SolarIconsOutline.squareShareLine;
  static const download = SolarIconsOutline.downloadSquare;
  static const copy = SolarIconsOutline.clipboardList;

  // Media & Files
  static const image = SolarIconsOutline.gallery;
  static const document = SolarIconsOutline.documentText;
  static const folder = SolarIconsOutline.folder;
  static const folderOpen = SolarIconsOutline.folder2;
  static const camera = SolarIconsOutline.camera;
  static const scanner = SolarIconsOutline.scanner;
  static const calendar = SolarIconsOutline.calendarDate;

  // Security & Auth
  static const shield = SolarIconsOutline.shieldCheck;
  static const lock = SolarIconsOutline.lock;
  static const login = SolarIconsOutline.login;
  static const logout = SolarIconsOutline.logout;

  // Status & Cloud
  static const cloud = SolarIconsOutline.cloud;
  static const cloudOff = SolarIconsOutline.cloudCross;
  static const offline = SolarIconsOutline.cloudCross;
  static const inbox = SolarIconsOutline.inbox;

  // Appearance & Settings
  static const lightMode = SolarIconsOutline.sun2;
  static const darkMode = SolarIconsOutline.moon;
  static const palette = SolarIconsOutline.paletteRound;
  static const language = SolarIconsOutline.global;
}


import 'package:flutter/material.dart';

abstract class CustomTextStyle {
  static const h1Bold = TextStyle(fontWeight: FontWeight.w700, fontSize: 40);
  static const h1Medium = TextStyle(fontWeight: FontWeight.w500, fontSize: 40);
  static const h1Regular = TextStyle(fontWeight: FontWeight.w400, fontSize: 40);
  static const h2Bold = TextStyle(fontWeight: FontWeight.w700, fontSize: 32);
  static const h2Medium = TextStyle(fontWeight: FontWeight.w500, fontSize: 32);
  static const h2Regular = TextStyle(fontWeight: FontWeight.w400, fontSize: 32);
  static const h3Bold = TextStyle(fontWeight: FontWeight.w700, fontSize: 24);
  static const h3Medium = TextStyle(fontWeight: FontWeight.w500, fontSize: 24);
  static const h3Regular = TextStyle(fontWeight: FontWeight.w400, fontSize: 24);
  static const h4Bold = TextStyle(fontWeight: FontWeight.w700, fontSize: 20);
  static const h4Medium = TextStyle(fontWeight: FontWeight.w500, fontSize: 20);
  static const h4Regular = TextStyle(fontWeight: FontWeight.w400, fontSize: 20);
  static const bodyBold = TextStyle(fontWeight: FontWeight.w700, fontSize: 16);
  static const bodySemiBold =
      TextStyle(fontWeight: FontWeight.w600, fontSize: 16);
  static const bodyMedium =
      TextStyle(fontWeight: FontWeight.w500, fontSize: 16);
  static const bodyRegular =
      TextStyle(fontWeight: FontWeight.w400, fontSize: 16);
  static const captionBold =
      TextStyle(fontWeight: FontWeight.w700, fontSize: 14);
  static const captionSemiBold =
      TextStyle(fontWeight: FontWeight.w600, fontSize: 14);
  static const captionMedium =
      TextStyle(fontWeight: FontWeight.w500, fontSize: 14);
  static const captionRegular =
      TextStyle(fontWeight: FontWeight.w400, fontSize: 14);
}

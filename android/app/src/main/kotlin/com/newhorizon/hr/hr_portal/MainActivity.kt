package com.newhorizon.hr.hr_portal

import io.flutter.embedding.android.FlutterFragmentActivity

// awesome_notifications يتطلب FlutterFragmentActivity (وليس FlutterActivity)
// لكي تعمل الإجراءات/الردود من الإشعار بشكل صحيح في كل الحالات.
class MainActivity : FlutterFragmentActivity()

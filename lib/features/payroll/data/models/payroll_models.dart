// ⚠️ API CONTRACT v1.0.0 — Fields match §10.7 exactly.

import 'package:equatable/equatable.dart';

import '../../../../core/network/pagination.dart';

/// A single line item within a payslip.
///
/// Represents one earning or deduction row.
class PayslipLine extends Equatable {
  final String? ruleCode;
  final String? ruleName;
  final String type;      // earning|deduction
  final double amount;
  final double quantity;
  final double rate;

  const PayslipLine({
    this.ruleCode,
    this.ruleName,
    required this.type,
    required this.amount,
    required this.quantity,
    required this.rate,
  });

  factory PayslipLine.fromJson(Map<String, dynamic> json) {
    return PayslipLine(
      ruleCode: json['rule_code'] as String?,
      ruleName: json['rule_name'] as String?,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'rule_code': ruleCode,
        'rule_name': ruleName,
        'type': type,
        'amount': amount,
        'quantity': quantity,
        'rate': rate,
      };

  bool get isEarning => type == 'earning';
  bool get isDeduction => type == 'deduction';

  @override
  List<Object?> get props => [ruleCode, type, amount];
}

/// Employee payslip for a specific pay period.
///
/// Contract: §10.7 Payslip
///
/// الحقول الجديدة لحالة الدفع (مضافة من السيرفر منذ آخر تحديث):
/// - [runStatus]: حالة الـ run الأب (`posted` / `partially_paid` / `paid`).
/// - [paidAmount]: المبلغ المستلم فعلياً.
/// - [remainingAmount]: المتبقي = `totalNet - paidAmount`.
/// - [isFullyPaid]: `true` إذا اكتمل الدفع.
/// - [paymentProgressPct]: نسبة 0..100 (للـ progress bar).
/// - [paymentStatement]: ملاحظة الدفع من HR (إن وُجدت).
///
/// كل الحقول الجديدة لها قيم افتراضية فلا يقع crash على ردود قديمة.
class Payslip extends Equatable {
  // ── Non-nullable ──
  final int id;
  final String status;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;

  // ── Nullable ──
  final String? runNo;
  final String? periodStart;     // Y-m-d
  final String? periodEnd;       // Y-m-d
  final String? frequency;
  final String? currency;
  final List<PayslipLine>? lines; // Only in detail view
  final String? paymentMethod;
  final String? paidAt;          // Y-m-d H:i:s

  // ── Payment status (new) ──
  final String? runStatus;        // posted | partially_paid | paid
  final double paidAmount;
  final double remainingAmount;
  final bool isFullyPaid;
  final int paymentProgressPct;   // 0..100
  final String? paymentStatement;

  const Payslip({
    required this.id,
    required this.status,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNet,
    this.runNo,
    this.periodStart,
    this.periodEnd,
    this.frequency,
    this.currency,
    this.lines,
    this.paymentMethod,
    this.paidAt,
    this.runStatus,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.isFullyPaid = false,
    this.paymentProgressPct = 0,
    this.paymentStatement,
  });

  factory Payslip.fromJson(Map<String, dynamic> json) {
    // Helpers — يتعاملون مع غياب الحقل (نسخ قديمة من السيرفر).
    double d(String key) => (json[key] as num?)?.toDouble() ?? 0;
    int i(String key) => (json[key] as num?)?.toInt() ?? 0;

    return Payslip(
      id: json['id'] as int,
      status: json['status'] as String,
      totalGross: (json['total_gross'] as num).toDouble(),
      totalDeductions: (json['total_deductions'] as num).toDouble(),
      totalNet: (json['total_net'] as num).toDouble(),
      runNo: json['run_no'] as String?,
      periodStart: json['period_start'] as String?,
      periodEnd: json['period_end'] as String?,
      frequency: json['frequency'] as String?,
      currency: json['currency'] as String?,
      lines: json['lines'] != null
          ? (json['lines'] as List)
              .map((e) => PayslipLine.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      paymentMethod: json['payment_method'] as String?,
      paidAt: json['paid_at'] as String?,
      runStatus: json['run_status'] as String?,
      paidAmount: d('paid_amount'),
      remainingAmount: d('remaining_amount'),
      isFullyPaid: json['is_fully_paid'] as bool? ?? false,
      paymentProgressPct: i('payment_progress_pct'),
      paymentStatement: json['payment_statement'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'total_gross': totalGross,
        'total_deductions': totalDeductions,
        'total_net': totalNet,
        'run_no': runNo,
        'period_start': periodStart,
        'period_end': periodEnd,
        'frequency': frequency,
        'currency': currency,
        'lines': lines?.map((l) => l.toJson()).toList(),
        'payment_method': paymentMethod,
        'paid_at': paidAt,
        'run_status': runStatus,
        'paid_amount': paidAmount,
        'remaining_amount': remainingAmount,
        'is_fully_paid': isFullyPaid,
        'payment_progress_pct': paymentProgressPct,
        'payment_statement': paymentStatement,
      };

  @override
  List<Object?> get props => [id];
}

/// Parsed data from GET /payroll.
///
/// Contract: §7.1 — `{payslips, pagination}`
class PayrollData {
  final List<Payslip> payslips;
  final Pagination pagination;

  const PayrollData({
    required this.payslips,
    required this.pagination,
  });

  factory PayrollData.fromJson(Map<String, dynamic> json) {
    return PayrollData(
      payslips: (json['payslips'] as List)
          .map((e) => Payslip.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}

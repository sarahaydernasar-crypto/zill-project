/// تقدير أولي لأثر تشجير موقع. كل الأرقام نطاقات مبنية على الافتراضات أدناه، وليست نتائج مضمونة.
class ImpactAssumptions {
  /// افتراض تخطيطي: تباعد بين 10 أمتار و6 أمتار بين الأشجار
  static const treesPerHaLow = 100.0;
  static const treesPerHaHigh = 278.0;

  /// افتراض تخطيطي: نسبة الموقع التي تغطيها تيجان الأشجار بعد نضجها
  static const canopyShareLow = 0.3;
  static const canopyShareHigh = 0.6;

  /// Nowak et al. 2013: نحو 0.28 كغم كربون لكل م² من الظلة سنوياً (متوسط الولايات المتحدة)،
  /// مضروباً في 3.67 للتحويل إلى ثاني أكسيد الكربون
  static const kgCo2PerCanopyM2 = 0.28 * 3.67;

  /// Bowler et al. 2010: الحديقة أبرد بنحو 1°م نهاراً. Knight et al. 2021: الغابات الحضرية بنحو 1.6°م.
  /// الرقمان لحرارة الهواء، ومعظم الدراسات من مناخات أخرى.
  static const coolingLowC = 1.0;
  static const coolingHighC = 1.6;

  static const sources = <(String, String)>[
    ('Knight et al. 2021: مراجعة منهجية لأثر التخضير على الجزر الحرارية',
        'https://research.bangor.ac.uk/en/publications/how-effective-is-greening-of-urban-areas-in-reducing-human-exposu/'),
    ('Bowler et al. 2010: مراجعة منهجية لأثر المساحات الخضراء الحضرية',
        'https://www.environmentalevidence.org/SR41.html'),
    ('Nowak et al. 2013: تخزين الكربون في أشجار المدن الأمريكية',
        'https://agris.fao.org/search/en/records/65e0076a7c7033e84befcb65'),
  ];
}

class SiteImpact {
  SiteImpact(this.areaHa);
  final double areaHa;

  int get treesLow => (areaHa * ImpactAssumptions.treesPerHaLow).round();
  int get treesHigh => (areaHa * ImpactAssumptions.treesPerHaHigh).round();

  double get canopyHaLow => areaHa * ImpactAssumptions.canopyShareLow;
  double get canopyHaHigh => areaHa * ImpactAssumptions.canopyShareHigh;

  double get co2TonsPerYearLow => canopyHaLow * 10000 * ImpactAssumptions.kgCo2PerCanopyM2 / 1000;
  double get co2TonsPerYearHigh => canopyHaHigh * 10000 * ImpactAssumptions.kgCo2PerCanopyM2 / 1000;
}

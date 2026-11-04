/// قيم النقاط الخضراء، وهي أمثلة أولية قابلة للتعديل من هنا
class GreenPoints {
  static const treesPerReward = 3;
  static const pointsPerReward = 2;
  static const redeemPoints = 50;

  /// لكل مجموعة كاملة من الأشجار نقاطها، والأشجار المتبقية لا تُحسب حتى تكتمل المجموعة
  static int forTrees(int trees) => trees ~/ treesPerReward * pointsPerReward;

  /// عدد الأشجار اللازم للوصول إلى حد الاستبدال من الزراعة وحدها
  static int get treesToRedeem => (redeemPoints / pointsPerReward).ceil() * treesPerReward;

  static const earnWays = <({String title, String detail, int points})>[
    (title: 'زراعة $treesPerReward أشجار', detail: 'لكل $treesPerReward أشجار يعتمدها المشرف', points: pointsPerReward),
    (title: 'المشاركة في حملة تشجير', detail: 'لكل حملة تحضرها', points: 5),
    (title: 'بقاء الشجرة حية بعد سنة', detail: 'لكل شجرة، بعد إرسال صورة حديثة لها', points: 3),
    (title: 'متابعة نمو الشجرة', detail: 'لكل صورة متابعة تُعتمد', points: 1),
    (title: 'بلاغ صحيح', detail: 'لكل بلاغ يعتمده المشرف', points: 1),
  ];
}

/// Banking apps that refuse to run while a third-party accessibility service
/// is enabled. The bank guard turns OpenBlock's service off while one of them
/// is in front. Users can add or remove apps in Settings.
abstract final class BankApps {
  static const labels = {
    'com.nu.production': 'Nubank',
    'com.itau': 'Itaú',
    'br.com.bb.android': 'Banco do Brasil',
    'com.bradesco': 'Bradesco',
    'br.com.gabba.Caixa': 'Caixa',
    'com.santander.app': 'Santander',
    'br.com.intermedium': 'Inter',
    'com.c6bank.app': 'C6 Bank',
    'com.picpay': 'PicPay',
    'com.mercadopago.wallet': 'Mercado Pago',
  };

  static final defaults = List<String>.unmodifiable(labels.keys);

  /// Command that grants the permission the guard needs to turn the
  /// accessibility service back on. Only ADB can grant it.
  static const adbGrantCommand =
      'adb shell pm grant dev.openblock.app android.permission.WRITE_SECURE_SETTINGS';
}

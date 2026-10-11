class AppConfig {
  static const String appName = 'Salva Bolso';

  /*
    Android Emulator:
    Use 10.0.2.2 para acessar o backend rodando no seu computador.

    App Web/Chrome no mesmo PC:
    http://127.0.0.1:8000/api

    Celular físico:
    http://IP_DO_SEU_PC:8000/api
    ou futuramente o IP da Tailscale.
  */
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api';
}
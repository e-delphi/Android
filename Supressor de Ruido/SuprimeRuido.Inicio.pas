// Eduardo - 14/05/2023
unit SuprimeRuido.Inicio;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Memo.Types,
  FMX.ScrollBox,
  FMX.Memo,

  IdGlobal,
  System.Threading,
  System.Permissions,

  Androidapi.Jni,
  Androidapi.JNI.Media,
  Androidapi.JNIBridge,
  Androidapi.Helpers,
  Androidapi.JNI.Os,
  Androidapi.Jni.JavaTypes,

  FMX.Platform.Android,
  System.IOUtils,
  FMX.Helpers.Android,
  Androidapi.JNI.GraphicsContentViewText,

  rnnoise.wrapper,
  wav;

type
  TInicio = class(TForm)
    btnCapturar: TButton;
    btnPermissao: TButton;
    btnPararCaptura: TButton;
    btnReproduzir: TButton;
    btnPararReproducao: TButton;
    btnDenoise: TButton;
    btnSalvar: TButton;
    btnArmazenamento: TButton;
    procedure btnCapturarClick(Sender: TObject);
    procedure btnPermissaoClick(Sender: TObject);
    procedure btnPararCapturaClick(Sender: TObject);
    procedure btnReproduzirClick(Sender: TObject);
    procedure btnPararReproducaoClick(Sender: TObject);
    procedure btnDenoiseClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnArmazenamentoClick(Sender: TObject);
  private
    // Geral
    FAudioFormat: Integer;
    FChannelINConfig: Integer;
    FChannelOUTConfig: Integer;
    FMinINBuffSize: Integer;
    FMinOUTBuffSize: Integer;
    FSampleRate: Integer;
    FAudioCapturado: TArray<Single>;

    // Captura
    FRecorder: JAudioRecord;
    FBytes: TJavaArray<Single>;
    ThreadLoopCaptura: ITask;

    // Reprodução
    FPlayer: JAudioTrack;
    ThreadLoopReproducao: ITask;

    // Rnnoise
    Denoiser: TDenoiser;

    // Captura
    procedure LoopCaptura;
    procedure LoopReproducao;
  end;

var
  Inicio: TInicio;

const
  RECORDSTATE_RECORDING = 3;

implementation

{$R *.fmx}

procedure TInicio.FormCreate(Sender: TObject);
begin
  Denoiser          := TDenoiser.Create;
  FSampleRate       := 48000;
  FAudioFormat      := TJAudioFormat.JavaClass.ENCODING_PCM_FLOAT;
  FChannelINConfig  := TJAudioFormat.JavaClass.CHANNEL_IN_MONO;
  FChannelOUTConfig := TJAudioFormat.JavaClass.CHANNEL_OUT_MONO;
  FMinINBuffSize    := TJAudioRecord.JavaClass.getMinBufferSize(FSampleRate, FChannelINConfig, FAudioFormat);
  FMinOUTBuffSize   := TJAudioTrack.JavaClass.getMinBufferSize(FSampleRate, FChannelOUTConfig, FAudioFormat);

  FBytes := TJavaArray<Single>.Create(FMinINBuffSize div SizeOf(Single));

  FRecorder := TJAudioRecord.JavaClass.init(
    TJMediaRecorder_AudioSource.JavaClass.MIC,
    FSampleRate,
    FChannelINConfig,
    FAudioFormat,
    FMinINBuffSize
  );

  FPlayer := TJAudioTrack.JavaClass.init(
    TJAudioManager.JavaClass.STREAM_MUSIC,
    FSampleRate,
    FChannelOUTConfig,
    FAudioFormat,
    FMinOUTBuffSize,
    TJAudioTrack.JavaClass.MODE_STREAM
  );
end;

procedure TInicio.FormDestroy(Sender: TObject);
begin
  FreeAndNil(Denoiser);
end;

procedure TInicio.btnPermissaoClick(Sender: TObject);
begin
  if PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.RECORD_AUDIO)) then
    Exit;

  PermissionsService.RequestPermissions(
    [JStringToString(TJManifest_permission.JavaClass.RECORD_AUDIO)],
    procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
    begin
      if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
        ShowMessage('Acesso concedido!')
      else
        ShowMessage('Acesso negado!')
    end
  );
end;

procedure TInicio.btnCapturarClick(Sender: TObject);
begin
  if not PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.RECORD_AUDIO)) then
  begin
    ShowMessage('Permita primeiro que o aplicativo capture o audio!');
    Exit;
  end;

  FAudioCapturado := [];

  FRecorder.startRecording;

  ThreadLoopCaptura := TTask.Run(LoopCaptura);
end;

procedure TInicio.LoopCaptura;
var
  Len: Integer;
  Bytes: TArray<Single>;
begin
  Sleep(100);
  while (FRecorder as JAudioRecord).getRecordingState = RECORDSTATE_RECORDING do
  begin
    Len := (FRecorder as JAudioRecord).read(FBytes, 0, FBytes.Length, 0);

    Bytes := [];
    SetLength(Bytes, Len);
    if FBytes.Length > 0 then
      System.Move(FBytes.Data^, Bytes[0], Len);

    // Pacote de audio capturado -> Bytes
    FAudioCapturado := FAudioCapturado + Bytes;
  end;
end;

procedure TInicio.btnPararCapturaClick(Sender: TObject);
begin
  FRecorder.stop;
end;

procedure TInicio.btnArmazenamentoClick(Sender: TObject);
begin
  if PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE)) then
    Exit;

  PermissionsService.RequestPermissions(
    [JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE)],
    procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
    begin
      if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
        ShowMessage('Acesso concedido!')
      else
        ShowMessage('Acesso negado!')
    end
  );
end;

procedure TInicio.btnSalvarClick(Sender: TObject);
begin
  if not PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE)) then
  begin
    ShowMessage('Permita primeiro que o aplicativo grave no armazenamento interno!');
    Exit;
  end;

  wav.Teste(TPath.Combine(TPath.GetSharedMusicPath, 'teste.wav'));
//  wav.SaveWaveToFile(FSampleRate, 16, FAudioCapturado, TPath.Combine(TPath.GetSharedMusicPath, 'teste.wav'));
end;

procedure TInicio.btnDenoiseClick(Sender: TObject);
var
  Entrada: TDenoiser.TAudioFrame;
  Saida: TDenoiser.TAudioFrame;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  J := 0;
  System.FillChar(Entrada, SizeOf(Entrada), 0);
  System.FillChar(Saida, SizeOf(Saida), 0);

  for I := 0 to Length(FAudioCapturado) -1 do
  begin
    if (I > 0) and (I mod 480 = 0) then
    begin
      Denoiser.Process(Entrada, Saida);

      for K := 0 to Length(Saida) -1 do
        FAudioCapturado[I - 480 + K] := Saida[K];

      J := 0;
    end;

    Entrada[J] := FAudioCapturado[I];
    Inc(J);
  end;
end;

procedure TInicio.btnReproduzirClick(Sender: TObject);
begin
  (FPlayer as JAudioTrack).play;
  ThreadLoopReproducao := TTask.Run(LoopReproducao);
end;

procedure TInicio.LoopReproducao;
var
  Audio: TJavaArray<Single>;
  Bytes: TArray<Single>;
  I: Integer;
  J: Integer;
begin
  SetLength(Bytes, FBytes.Length);

  J := 0;
  for I := 0 to Length(FAudioCapturado) -1 do
  begin
    if (I > 0) and (I mod FBytes.Length = 0) then
    begin
      Audio := TJavaArray<Single>.Create(Length(Bytes));
      if Length(Bytes) > 0 then
        System.Move(Bytes[0], Audio.Data^, Length(Bytes));
      (FPlayer as JAudioTrack).write(Audio, 0, Audio.Length, 0);

      J := 0;
    end;

    Bytes[J] := FAudioCapturado[I];
    Inc(J);
  end;
end;

procedure TInicio.btnPararReproducaoClick(Sender: TObject);
begin
  (FPlayer as JAudioTrack).stop;
end;

end.


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
    // Captura
    FRecorder: JAudioRecord;
    FBytes: TJavaArray<Byte>;
    ThreadLoopCaptura: ITask;

    // Reprodução
    FPlay: JAudioTrack;
    ThreadLoopReproducao: ITask;

    // Rnnoise
    Denoiser: TDenoiser;

    // Captura
    procedure LoopCaptura;
    procedure LoopReproducao;
  public
    AudioCapturado: TWaveformSamples;
  end;

var
  Inicio: TInicio;

const
  sampleRate: Integer = 48000;
  RECORDSTATE_RECORDING = 3;

implementation

{$R *.fmx}

procedure TInicio.FormCreate(Sender: TObject);
begin
  Denoiser := TDenoiser.Create;
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
    procedure(const APermissions: TArray<String>; const AGrantResults: TArray<TPermissionStatus>)
    begin
      if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
        ShowMessage('Acesso concedido!')
      else
        ShowMessage('Acesso negado!')
    end
  );
end;

procedure TInicio.LoopCaptura;
var
  Len: Integer;
  Bytes: TWaveformSamples;
begin
  while (FRecorder as JAudioRecord).getRecordingState = RECORDSTATE_RECORDING do
  begin
    Len := (FRecorder as JAudioRecord).read(FBytes, 0, FBytes.Length);

    Bytes := [];
    SetLength(Bytes, Len);
    if FBytes.Length > 0 then
      System.Move(FBytes.Data^, Bytes[0], Len);

    // Pacote de audio capturado -> Bytes
    AudioCapturado := AudioCapturado + Bytes;
  end;
end;

procedure TInicio.btnCapturarClick(Sender: TObject);
var
  channelConfig: Integer;
  audioFormat: Integer;
  minBufSize: Integer;
begin
  if not PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.RECORD_AUDIO)) then
  begin
    ShowMessage('Permita primeiro que o aplicativo capture o audio!');
    Exit;
  end;

  AudioCapturado := [];

  if Assigned(FRecorder) then
  begin
    FRecorder := nil;
    FBytes.DisposeOf;
  end;

  channelConfig := TJAudioFormat.JavaClass.CHANNEL_IN_MONO;
  audioFormat := TJAudioFormat.JavaClass.ENCODING_PCM_16BIT;
  minBufSize := TJAudioRecord.JavaClass.getMinBufferSize(sampleRate, channelConfig, audioFormat);

  FBytes := TJavaArray<Byte>.Create(minBufSize * 4);
  FRecorder := TJAudioRecord.JavaClass.init(TJMediaRecorder_AudioSource.JavaClass.MIC, sampleRate, channelConfig, audioFormat, minBufSize * 4);

  FRecorder.startRecording;

  ThreadLoopCaptura := TTask.Run(LoopCaptura);
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
    procedure(const APermissions: TArray<String>; const AGrantResults: TArray<TPermissionStatus>)
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

  wav.SaveWaveToFile(sampleRate, 16, AudioCapturado, TPath.Combine(TPath.GetSharedMusicPath, 'teste.wav'));
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

  for I := 0 to Length(AudioCapturado) -1 do
  begin
    if (I > 0) and (I mod 480 = 0) then
    begin
      Denoiser.Process(Entrada, Saida);

      for K := 0 to Length(Saida) -1 do
        AudioCapturado[I - 480 + K] := Trunc(Saida[K]);

      J := 0;
    end;

    Entrada[J] := AudioCapturado[I];
    Inc(J);
  end;
end;

procedure TInicio.LoopReproducao;
var
  Audio: TJavaArray<Byte>;
  Bytes: TArray<SmallInt>;
  I: Integer;
  J: Integer;
begin
  SetLength(Bytes, FBytes.Length);

  J := 0;
  for I := 0 to Length(AudioCapturado) -1 do
  begin
    if (I > 0) and (I mod FBytes.Length = 0) then
    begin
      Audio := TJavaArray<Byte>.Create(Length(Bytes));
      if Length(Bytes) > 0 then
        System.Move(Bytes[0], Audio.Data^, Length(Bytes));
      (FPlay as JAudioTrack).write(Audio, 0, Audio.Length);

      J := 0;
    end;

    Bytes[J] := AudioCapturado[I];
    Inc(J);
  end;
end;

procedure TInicio.btnReproduzirClick(Sender: TObject);
var
  trackmin: Integer;
begin
  trackmin := TJAudioTrack.JavaClass.getMinBufferSize(
    sampleRate,
    TJAudioFormat.JavaClass.CHANNEL_OUT_MONO,
    TJAudioFormat.JavaClass.ENCODING_PCM_16BIT
  );

  FPlay := TJAudioTrack.JavaClass.init(
    TJAudioManager.JavaClass.STREAM_MUSIC,
    sampleRate,
    TJAudioFormat.JavaClass.CHANNEL_OUT_MONO,
    TJAudioFormat.JavaClass.ENCODING_PCM_16BIT,
    trackmin,
    TJAudioTrack.JavaClass.MODE_STREAM
  );

  (FPlay as JAudioTrack).play;
  ThreadLoopReproducao := TTask.Run(LoopReproducao);
end;

procedure TInicio.btnPararReproducaoClick(Sender: TObject);
begin
  (FPlay as JAudioTrack).stop;
end;

end.


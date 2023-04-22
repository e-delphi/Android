// Eduardo - 21/04/2023
unit ReproduzAudio.Inicio;

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
  Androidapi.Jni.JavaTypes;

type
  TInicio = class(TForm)
    btnCapturar: TButton;
    btnPermissao: TButton;
    btnPararCaptura: TButton;
    btnReproduzir: TButton;
    btnPararReproducao: TButton;
    procedure btnCapturarClick(Sender: TObject);
    procedure btnPermissaoClick(Sender: TObject);
    procedure btnPararCapturaClick(Sender: TObject);
    procedure btnReproduzirClick(Sender: TObject);
    procedure btnPararReproducaoClick(Sender: TObject);
  private
    // Captura
    FRecorder: JAudioRecord;
    FBytes: TJavaArray<Byte>;
    ThreadLoopCaptura: ITask;

    // Reprodução
    FPlay: JAudioTrack;
    ThreadLoopReproducao: ITask;

    // Captura
    procedure LoopCaptura;
    procedure LoopReproducao;
  public
    AudioCapturado: TArray<TIdBytes>;
  end;

var
  Inicio: TInicio;

const
  sampleRate: Integer = 11025;
  RECORDSTATE_RECORDING = 3;

implementation

{$R *.fmx}

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
  Bytes: TIdBytes;
begin
  while (FRecorder as JAudioRecord).getRecordingState = RECORDSTATE_RECORDING do
  begin
    (FRecorder as JAudioRecord).read(FBytes, 0, FBytes.Length);

    Len := FBytes.Length;
    Bytes := [];
    SetLength(Bytes, Len);
    if Len > 0 then
      System.Move(FBytes.Data^, Bytes[0], Len);

    // Pacote de audio capturado -> Bytes
    AudioCapturado := AudioCapturado + [Bytes];
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

  (FRecorder as JAudioRecord).startRecording;
  ThreadLoopCaptura := TTask.Run(LoopCaptura);
end;

procedure TInicio.btnPararCapturaClick(Sender: TObject);
begin
  (FRecorder as JAudioRecord).stop;
end;

procedure TInicio.LoopReproducao;
var
  Audio: TJavaArray<Byte>;
  I: Integer;
  Bytes: TIdBytes;
begin
  for I := 0 to Pred(Length(AudioCapturado)) do
  begin
    Bytes := AudioCapturado[I];

    Audio := TJavaArray<Byte>.Create(Length(Bytes));

    if Length(Bytes) > 0 then
      System.Move(Bytes[0], Audio.Data^, Length(Bytes));

    (FPlay AS JAudioTrack).write(Audio, 0, Audio.Length);
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


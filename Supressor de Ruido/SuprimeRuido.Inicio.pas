// Eduardo - 14/05/2023
unit SuprimeRuido.Inicio;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
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
    mm: TMemo;
    lbDividir: TLabel;
    swDividir: TSwitch;
    btnLog: TButton;
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
    procedure btnLogClick(Sender: TObject);
  private
    // Geral
    FAudioFormat: Integer;
    FChannelINConfig: Integer;
    FChannelOUTConfig: Integer;
    FMinINBuffSize: Integer;
    FMinOUTBuffSize: Integer;
    FSampleRate: Integer;
    FAudioCapturado: TArray<TArray<Single>>;

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
  FSampleRate       := 48000;
  FAudioFormat      := TJAudioFormat.JavaClass.ENCODING_PCM_FLOAT;
  FChannelINConfig  := TJAudioFormat.JavaClass.CHANNEL_IN_MONO;
  FChannelOUTConfig := TJAudioFormat.JavaClass.CHANNEL_OUT_MONO;
  FMinINBuffSize    := TJAudioRecord.JavaClass.getMinBufferSize(FSampleRate, FChannelINConfig, FAudioFormat);
  FMinOUTBuffSize   := TJAudioTrack.JavaClass.getMinBufferSize(FSampleRate, FChannelOUTConfig, FAudioFormat);

  FBytes := TJavaArray<Single>.Create(FMinINBuffSize);

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
  Amostra: TArray<Single>;
  I: Integer;
begin
  while (FRecorder as JAudioRecord).getRecordingState = RECORDSTATE_RECORDING do
  begin
    Len := (FRecorder as JAudioRecord).read(FBytes, 0, FBytes.Length, 0);

    if Len = 0 then
      Continue;

    Amostra := [];
    SetLength(Amostra, Len);

    for I := 0 to Len do
      Amostra[I] := FBytes.Items[I];

    FAudioCapturado := FAudioCapturado + [Amostra];
  end;
end;

procedure TInicio.btnPararCapturaClick(Sender: TObject);
begin
  (FRecorder as JAudioRecord).stop;
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
var
  Audio: TArray<Single>;
  I: Integer;
begin
  if not PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE)) then
  begin
    ShowMessage('Permita primeiro que o aplicativo grave no armazenamento interno!');
    Exit;
  end;

  Audio := [];
  for I := 0 to Pred(Length(FAudioCapturado)) do
    Audio := Audio + FAudioCapturado[I];

  wav.SaveWaveToFile(FSampleRate, 16, wav.ConvertFloatToSmallInt(Audio), TPath.Combine(TPath.GetSharedMusicPath, 'teste.wav'));
end;

procedure TInicio.btnLogClick(Sender: TObject);
var
  I: Integer;
  s: String;
  J: Integer;
begin
  s := '';
  for I := 0 to Pred(Length(FAudioCapturado)) do
  begin
    s := s +'[';
    for J := 0 to Min(Pred(Length(FAudioCapturado[I])), 9) do
      s := s + FAudioCapturado[I, J].ToString +',';
    s := s +']';
  end;

  mm.Lines.Add(s);
end;

procedure TInicio.btnDenoiseClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to Pred(Length(FAudioCapturado)) do
    Denoiser.Process(FAudioCapturado[I], swDividir.IsChecked);
end;

procedure TInicio.btnReproduzirClick(Sender: TObject);
begin
  (FPlayer as JAudioTrack).play;
  ThreadLoopReproducao := TTask.Run(LoopReproducao);
end;

procedure TInicio.LoopReproducao;
var
  Audio: TJavaArray<Single>;
  I, J: Integer;
begin
  for I := 0 to Pred(Length(FAudioCapturado)) do
  begin
    Audio := TJavaArray<Single>.Create(Length(FAudioCapturado[I]));

    for J := 0 to Pred(Length(FAudioCapturado[I])) do
      Audio.Items[J] := FAudioCapturado[I, J];

    (FPlayer AS JAudioTrack).write(Audio, 0, Audio.Length, 0);
  end;
end;

procedure TInicio.btnPararReproducaoClick(Sender: TObject);
begin
  (FPlayer as JAudioTrack).stop;
end;

end.


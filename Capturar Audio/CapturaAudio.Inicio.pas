// Eduardo - 21/04/2023
unit CapturaAudio.Inicio;

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
    btnCriar: TButton;
    btnCapturar: TButton;
    btnPermissao: TButton;
    btnParar: TButton;
    btnDestruir: TButton;
    mmLog: TMemo;
    procedure btnCriarClick(Sender: TObject);
    procedure btnCapturarClick(Sender: TObject);
    procedure btnPermissaoClick(Sender: TObject);
    procedure btnPararClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnDestruirClick(Sender: TObject);
  private
    FRecorder: JAudioRecord;
    FBytes: TJavaArray<Byte>;
    Loop: ITask;
    procedure LoopCaptura;
  public
    AudioCapturado: TIdBytes;
  end;

var
  Inicio: TInicio;

const
  RECORDSTATE_RECORDING = 3;

implementation

{$R *.fmx}

procedure TInicio.FormCreate(Sender: TObject);
begin
  AudioCapturado := [];
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

procedure TInicio.btnCriarClick(Sender: TObject);
const
  sampleRate: Integer = 11025;
var
  channelConfig: Integer;
  audioFormat: Integer;
  minBufSize: Integer;
begin
  channelConfig := TJAudioFormat.JavaClass.CHANNEL_IN_MONO;
  audioFormat := TJAudioFormat.JavaClass.ENCODING_PCM_16BIT;
  minBufSize := TJAudioRecord.JavaClass.getMinBufferSize(sampleRate, channelConfig, audioFormat);

  FBytes := TJavaArray<Byte>.Create(minBufSize * 4);
  FRecorder := TJAudioRecord.JavaClass.init(TJMediaRecorder_AudioSource.JavaClass.MIC, sampleRate, channelConfig, audioFormat, minBufSize * 4);
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
    AudioCapturado := AudioCapturado + Bytes;

    TThread.Synchronize(
      nil,
      procedure
      begin
        mmLog.Lines.Insert(0, Length(AudioCapturado).ToString);
      end
    );
  end;
end;

procedure TInicio.btnCapturarClick(Sender: TObject);
begin
  if not PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.RECORD_AUDIO)) then
  begin
    ShowMessage('Permita primeiro que o aplicativo capture o audio!');
    Exit;
  end;

  (FRecorder as JAudioRecord).startRecording;
  Loop := TTask.Run(LoopCaptura);
end;

procedure TInicio.btnPararClick(Sender: TObject);
begin
  (FRecorder as JAudioRecord).stop;
end;

procedure TInicio.btnDestruirClick(Sender: TObject);
begin
  FBytes.DisposeOf;
end;

end.


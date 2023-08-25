﻿// Eduardo - 21/04/2023
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
    procedure FormCreate(Sender: TObject);
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


program CapturaAudio;

uses
  System.StartUpCopy,
  FMX.Forms,
  CapturaAudio.Inicio in 'CapturaAudio.Inicio.pas' {Inicio};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TInicio, Inicio);
  Application.Run;
end.

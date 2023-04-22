program ReproduzAudio;

uses
  System.StartUpCopy,
  FMX.Forms,
  ReproduzAudio.Inicio in 'ReproduzAudio.Inicio.pas' {Inicio};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TInicio, Inicio);
  Application.Run;
end.

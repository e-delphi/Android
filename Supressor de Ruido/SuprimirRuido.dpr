program SuprimirRuido;

uses
  System.StartUpCopy,
  FMX.Forms,
  SuprimeRuido.Inicio in 'SuprimeRuido.Inicio.pas' {Inicio},
  rnnoise.wrapper in 'rnnoise\rnnoise.wrapper.pas',
  wav in 'wav.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TInicio, Inicio);
  Application.Run;
end.

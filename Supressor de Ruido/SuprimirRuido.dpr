program SuprimirRuido;

uses
  System.StartUpCopy,
  FMX.Forms,
  SuprimeRuido.Inicio in 'SuprimeRuido.Inicio.pas' {Inicio};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TInicio, Inicio);
  Application.Run;
end.

// Eduardo - 13/05/2023
unit rnnoise.wrapper;

interface

type
  TDenoiser = class
  private const
    DLL_NAME = 'librnnoise.so';
    FRAME_SIZE = 480;
  private
    LIB_HND: HMODULE;
    state: Pointer;
    rnnoise_get_size: function: Integer; cdecl;
    rnnoise_init: function(state: Pointer; model: Pointer): Integer; cdecl;
    rnnoise_create: function(model: Pointer): Pointer; cdecl;
    rnnoise_destroy: procedure(state: Pointer); cdecl;
    rnnoise_process_frame: function(state: Pointer; dataOut, dataIn: PSingle): Single; cdecl;
  public type
    TAudioFrame = Array[0..FRAME_SIZE - 1] of Single;
  public
    constructor Create;
    destructor Destroy; override;
    function Process(const Input: TAudioFrame; var Output: TAudioFrame): Single;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

{ Denoiser }

constructor TDenoiser.Create;
var
  sLib: String;
begin
  LIB_HND := 0;
  sLib := TPath.Combine(TPath.GetDocumentsPath, DLL_NAME);

  if not TFile.Exists(sLib) then
    raise Exception.Create('Biblioteca "'+ DLL_NAME +'" n�o encontrada!');

  LIB_HND := LoadLibrary(PWideChar(sLib));

  if LIB_HND = 0 then
    raise Exception.Create('Erro ao carregar a biblioteca "'+ DLL_NAME +'"!');

  rnnoise_get_size      := GetProcAddress(LIB_HND, PChar('rnnoise_get_size'));
  rnnoise_init          := GetProcAddress(LIB_HND, PChar('rnnoise_init'));
  rnnoise_create        := GetProcAddress(LIB_HND, PChar('rnnoise_create'));
  rnnoise_destroy       := GetProcAddress(LIB_HND, PChar('rnnoise_destroy'));
  rnnoise_process_frame := GetProcAddress(LIB_HND, PChar('rnnoise_process_frame'));

  state := rnnoise_create(nil);
end;

destructor TDenoiser.Destroy;
begin
  if LIB_HND = 0 then
    Exit;

  rnnoise_destroy(state);
  FreeLibrary(LIB_HND);
end;

function TDenoiser.Process(const Input: TAudioFrame; var Output: TAudioFrame): Single;
begin
  Result := rnnoise_process_frame(state, @Output[0], @Input[0]);
end;

end.

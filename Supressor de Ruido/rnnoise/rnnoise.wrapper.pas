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
    function Process(var Frame: TArray<Single>; dividir: Boolean): Single;
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
    raise Exception.Create('Biblioteca "'+ DLL_NAME +'" não encontrada!');

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

function TDenoiser.Process(var Frame: TArray<Single>; dividir: Boolean): Single;
var
  Input: TAudioFrame;
  Output: TAudioFrame;
  I, J, K, L: Integer;
begin
  if dividir then
  begin
    J := 0;
    L := 0;
    Result := 0;
    for I := 0 to Pred(Length(Frame)) do
    begin
      if J = Pred(FRAME_SIZE) then
      begin
        Result := rnnoise_process_frame(state, @Output, @Input);
        for K := 0 to Pred(FRAME_SIZE) do
        begin
          Frame[L] := Output[K] / 32767;
          Inc(L);
        end;
        J := 0;
      end
      else
      begin
        Input[J] := Frame[I] * 32767;
        Inc(J);
      end;
    end;
  end
  else
  begin
    J := 0;
    L := 0;
    Result := 0;
    for I := 0 to Pred(Length(Frame)) do
    begin
      if J = Pred(FRAME_SIZE) then
      begin
        Result := rnnoise_process_frame(state, @Output, @Input);
        for K := 0 to Pred(FRAME_SIZE) do
        begin
          Frame[L] := Output[K];
          Inc(L);
        end;
        J := 0;
      end
      else
      begin
        Input[J] := Frame[I];
        Inc(J);
      end;
    end;
  end;
end;

end.

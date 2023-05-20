// Eduardo - 20/05/2023
unit wav;

interface

type
  TWaveformSample = SmallInt; // Integer 32-bit; -2147483648..2147483647; SmallInt 16-bit -32768..32767
  TWaveformSamples = packed array of TWaveformSample;

procedure SaveWaveToFile(const SamplesPerSec: Integer; const BitsPerSample: Integer; const WaveData: TWaveformSamples; const FileName: string);

implementation

uses
  System.SysUtils,
  System.Types,
  System.Classes;

function CreatePureSineTone(const AFreq: integer; const ADuration: integer; const AVolume: Integer; const iSamplesPerSec: Integer; const iBitsPerSample: Integer): TWaveformSamples;
var
  i: Integer;
  omega, dt, t: double;
  vol: double;
begin
  omega := 2 * Pi * AFreq;
  dt := 1 / iSamplesPerSec;
  t := 0;
  vol := MaxInt * (AVolume / 100);
  SetLength(Result, Round((ADuration / 1000) * iSamplesPerSec));
  case iBitsPerSample of
    16:
    begin
      for i := 0 to High(Result) do
      begin
        Result[i] := Round(vol * sin(omega * t)) div (MaxInt div High(SmallInt));
        t := t + dt;
      end;
    end;
    32:
    begin
      for i := 0 to High(Result) do
      begin
        Result[i] := Round(vol * sin(omega * t));
        t := t + dt;
      end;
    end;
  else
    raise Exception.Create('BitsPerSample não suportado!');
  end;
end;

function Crossfade(const WaveData1, WaveData2: TWaveformSamples; const iMSDuracao: Integer; const iSamplesPerSec: Integer): TWaveformSamples;
  function CrossfadeSample(const WaveData1, WaveData2: TWaveformSamples): TWaveformSamples;
  var
    i: Integer;
    CrossfadeFactor: Double;
    Sample1, Sample2: Double;
  begin
    // Verificar se os tamanhos das ondas são compatíveis
    if Length(WaveData1) <> Length(WaveData2) then
      raise Exception.Create('WaveData1 and WaveData2 must have the same length for crossfade.');

    SetLength(Result, Length(WaveData1));

    for i := 0 to High(Result) do
    begin
      CrossfadeFactor := i / High(Result); // Fator de mesclagem linear

      Sample1 := WaveData1[i] / MaxInt; // Normalizar a amostra para o intervalo -1 a 1
      Sample2 := WaveData2[i] / MaxInt; // Normalizar a amostra para o intervalo -1 a 1

      // Aplicar o fator de mesclagem e ajustar a amplitude
      Result[i] := Round((Sample1 * (1 - CrossfadeFactor) + Sample2 * CrossfadeFactor) * MaxInt);
    end;
  end;
var
  P1: TWaveformSamples;
  F1: TWaveformSamples;
  P2: TWaveformSamples;
  F2: TWaveformSamples;
  iFrames: Integer;
begin
  iFrames := Round(iSamplesPerSec * (iMSDuracao / 1000));

  F1 := Copy(WaveData1, Length(WaveData1) - iFrames);
  F2 := Copy(WaveData2, 0, iFrames);

  P1 := Copy(WaveData1, 0, Length(WaveData1) - iFrames);
  P2 := Copy(WaveData2, iFrames, Length(WaveData2) - iFrames);

  Result := P1 + CrossfadeSample(F1, F2) + P2;
end;

procedure SaveWaveToFile(const SamplesPerSec: Integer; const BitsPerSample: Integer; const WaveData: TWaveformSamples; const FileName: string);
const
  Channels: Integer = 1;
  PCM: Integer = 1;
var
  Stream: TFileStream;
  Header: TArray<Byte>;
  ChunkSize, FileSize: DWORD;
  Temp: Integer;
  ByteSize: Integer;
begin
  // Criação do stream de arquivo
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    // Geração do cabeçalho WAV
    SetLength(Header, 44); // Tamanho fixo do cabeçalho

    case BitsPerSample of
      16: ByteSize := SizeOf(SmallInt);
      32: ByteSize := SizeOf(Integer);
    else
      raise Exception.Create('BitsPerSample não suportado!');
    end;

    // Escrever o cabeçalho RIFF
    Move(BytesOf('RIFF')[0], Header[0], 4);
    ChunkSize := Length(WaveData) * ByteSize + 36; // Tamanho total do arquivo - 8
    Move(ChunkSize, Header[4], 4);
    Move(BytesOf('WAVE')[0], Header[8], 4);

    // Escrever o cabeçalho fmt
    Move(BytesOf('fmt ')[0], Header[12], 4);
    ChunkSize := 16; // Tamanho fixo para PCM
    Move(ChunkSize, Header[16], 4);
    Move(PCM, Header[20], 2); // Formato PCM
    Move(Channels, Header[22], 2);
    Move(SamplesPerSec, Header[24], 4);
    Temp := SamplesPerSec * Channels * (BitsPerSample div 8);
    Move(Temp, Header[28], 4);
    Temp := Channels * (BitsPerSample div 8);
    Move(Temp, Header[32], 2);
    Move(BitsPerSample, Header[34], 2);

    // Escrever o cabeçalho data
    Move(BytesOf('data')[0], Header[36], 4);
    FileSize := Length(WaveData) * ByteSize;
    Move(FileSize, Header[40], 4);

    // Gravação do cabeçalho no arquivo
    Stream.WriteBuffer(Header[0], Length(Header));

    // Gravação dos dados de amostra
    Stream.WriteBuffer(WaveData[0], FileSize);
  finally
    Stream.Free;
  end;
end;

//const
//  SamplesPerSec = 48000;
//  BitsPerSample = 16;
//  Duracao = 3000;
//  Volume = 50;
//var
//  Sp1, Sp2: TWaveformSamples;
//  Samples: TWaveformSamples;
//begin
//  Sp1 := CreatePureSineTone(60, Duracao, Volume, SamplesPerSec, BitsPerSample);
//  Sp2 := CreatePureSineTone(600, Duracao, Volume, SamplesPerSec, BitsPerSample);
//
//  Samples := Crossfade(Sp1, Sp2, 500, SamplesPerSec);
//
//  SaveWaveToFile(
//    SamplesPerSec,
//    BitsPerSample,
//    Samples,
//    'D:\teste.wav'
//  );
end.

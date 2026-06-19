unit Int64Em;

{
  Inno Setup
  Copyright (C) 1997-2025 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  Declaration of the Integer64 type - which represents an *unsigned* 64-bit
  integer value - and functions for manipulating Integer64's.
}

interface

type
  Integer64 = record
    Lo, Hi: LongWord;
    class operator Implicit(const A: Integer64): Int64;
    class operator Implicit(const A: Int64): Integer64;
  end;

function Compare64(const N1, N2: Integer64): Integer;
procedure Dec64(var X: Integer64; N: LongWord);
procedure Dec6464(var X: Integer64; const N: Integer64);
function Div64(var X: Integer64; const Divisor: LongWord): LongWord;
function Inc64(var X: Integer64; N: LongWord): Boolean;
function Inc6464(var X: Integer64; const N: Integer64): Boolean;
function Mod64(const X: Integer64; const Divisor: LongWord): LongWord;
procedure Multiply32x32to64(N1, N2: LongWord; var X: Integer64);
function StrToInteger64(const S: String; var X: Integer64): Boolean; overload;
function StrToInteger64(const S: String; var X: Int64): Boolean; overload;

implementation

uses
  SysUtils;

function Integer64ToUInt64(const X: Integer64): UInt64; inline;
begin
  Result := (UInt64(X.Hi) shl 32) or UInt64(X.Lo);
end;

procedure UInt64ToInteger64(const Value: UInt64; var X: Integer64); inline;
begin
  X.Lo := LongWord(Value);
  X.Hi := LongWord(Value shr 32);
end;

function Compare64(const N1, N2: Integer64): Integer;
{ If N1 = N2, returns 0.
  If N1 > N2, returns 1.
  If N1 < N2, returns -1. }
begin
  if (N1.Hi > N2.Hi) or ((N1.Hi = N2.Hi) and (N1.Lo > N2.Lo)) then
    Result := 1
  else if (N1.Hi < N2.Hi) or ((N1.Hi = N2.Hi) and (N1.Lo < N2.Lo)) then
    Result := -1
  else
    Result := 0;
end;

procedure Dec64(var X: Integer64; N: LongWord);
var
  OldLo: LongWord;
begin
  OldLo := X.Lo;
  if OldLo < N then begin
    X.Lo := LongWord((UInt64(1) shl 32) + UInt64(OldLo) - UInt64(N));
    Dec(X.Hi);
  end else
    X.Lo := OldLo - N;
end;

procedure Dec6464(var X: Integer64; const N: Integer64);
var
  Borrow: LongWord;
begin
  if X.Lo < N.Lo then begin
    X.Lo := LongWord((UInt64(1) shl 32) + UInt64(X.Lo) - UInt64(N.Lo));
    Borrow := 1;
  end else begin
    X.Lo := X.Lo - N.Lo;
    Borrow := 0;
  end;
  Dec(X.Hi, N.Hi);
  if Borrow <> 0 then
    Dec(X.Hi);
end;

function Inc64(var X: Integer64; N: LongWord): Boolean;
{ Adds N to X. In case of overflow, False is returned. }
var
  SumLo, SumHi: UInt64;
begin
  SumLo := UInt64(X.Lo) + UInt64(N);
  X.Lo := LongWord(SumLo);
  SumHi := UInt64(X.Hi) + (SumLo shr 32);
  X.Hi := LongWord(SumHi);
  Result := (SumHi shr 32) = 0;
end;

function Inc6464(var X: Integer64; const N: Integer64): Boolean;
{ Adds N to X. In case of overflow, False is returned. }
var
  SumLo, SumHi: UInt64;
begin
  SumLo := UInt64(X.Lo) + UInt64(N.Lo);
  X.Lo := LongWord(SumLo);
  SumHi := UInt64(X.Hi) + UInt64(N.Hi) + (SumLo shr 32);
  X.Hi := LongWord(SumHi);
  Result := (SumHi shr 32) = 0;
end;

procedure Multiply32x32to64(N1, N2: LongWord; var X: Integer64);
{ Multiplies two 32-bit unsigned integers together and places the result
  in X. }
var
  Product: UInt64;
begin
  Product := UInt64(N1) * UInt64(N2);
  UInt64ToInteger64(Product, X);
end;

function Mul64(var X: Integer64; N: LongWord): Boolean;
{ Multiplies X by N, and overwrites X with the result. In case of overflow,
  False is returned (X is valid but truncated to 64 bits). }
var
  HighProduct, LowProduct, NewHi: UInt64;
begin
  HighProduct := UInt64(X.Hi) * UInt64(N);
  LowProduct := UInt64(X.Lo) * UInt64(N);

  X.Lo := LongWord(LowProduct);
  NewHi := (HighProduct and $FFFFFFFF) + (LowProduct shr 32);
  X.Hi := LongWord(NewHi);

  Result := ((HighProduct shr 32) = 0) and ((NewHi shr 32) = 0);
end;

function Div64(var X: Integer64; const Divisor: LongWord): LongWord;
{ Divides X by Divisor, and overwrites X with the quotient. Returns the
  remainder. }
var
  Value: UInt64;
begin
  Value := Integer64ToUInt64(X);
  Result := LongWord(Value mod UInt64(Divisor));
  UInt64ToInteger64(Value div UInt64(Divisor), X);
end;

function Mod64(const X: Integer64; const Divisor: LongWord): LongWord;
{ Divides X by Divisor and returns the remainder. Unlike Div64, X is left
  intact. }
begin
  Result := LongWord(Integer64ToUInt64(X) mod UInt64(Divisor));
end;

function StrToInteger64(const S: String; var X: Integer64): Boolean;
{ Converts a string containing an unsigned decimal number, or hexadecimal
  number prefixed with '$', into an Integer64. Returns True if successful,
  or False if invalid characters were encountered or an overflow occurred.
  Supports digits separators. }
var
  Len, Base, StartIndex, I: Integer;
  V: Integer64;
  C: Char;
begin
  Result := False;

  Len := Length(S);
  Base := 10;
  StartIndex := 1;
  if Len > 0 then begin
    if S[1] = '$' then begin
      Base := 16;
      Inc(StartIndex);
    end else if S[1] = '_' then
      Exit;
  end;

  if (StartIndex > Len) or (S[StartIndex] = '_') then
    Exit;
  V := 0;
  for I := StartIndex to Len do begin
    C := UpCase(S[I]);
    case C of
      '0'..'9':
        begin
          if not Mul64(V, Base) then
            Exit;
          if not Inc64(V, Ord(C) - Ord('0')) then
            Exit;
        end;
      'A'..'F':
        begin
          if Base <> 16 then
            Exit;
          if not Mul64(V, Base) then
            Exit;
          if not Inc64(V, Ord(C) - (Ord('A') - 10)) then
            Exit;
        end;
      '_':
        { Ignore }
    else
      Exit;
    end;
  end;
  X := V;
  Result := True;
end;

function StrToInteger64(const S: String; var X: Int64): Boolean;
var
  X2: Integer64;
begin
  X2 := X;
  Result := StrToInteger64(S, X2);
  X := X2;
end;

{ Integer64 }

class operator Integer64.Implicit(const A: Int64): Integer64;
begin
  Int64Rec(Result) := Int64Rec(A);
end;

class operator Integer64.Implicit(const A: Integer64): Int64;
begin
  Int64Rec(Result) := Int64Rec(A);
end;

end.

// Eduardo - 10/11/2024
unit Pipa.Ordenacao;

interface

uses
  Pipa.Tipos;

procedure Ordenar(var Itens: TItens);

implementation

uses
  System.Math,
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults;

function ExtrairNumero(const Nome: string; out Numero: Int64): Boolean;
var
  I: Integer;
  NumeroStr: string;
begin
  NumeroStr := '';
  for I := 1 to Nome.Length do
  begin
    if CharInSet(Nome[I], ['0'..'9']) then
      NumeroStr := NumeroStr + Nome[I]
    else
      Break;
  end;
  if NumeroStr <> '' then
  begin
    Numero := StrToInt64(NumeroStr);
    Result := True;
  end
  else
  begin
    Numero := 0;
    Result := False;
  end;
end;

function Compara(const Left, Right: TItem): Integer;
var
  LeftIs: Boolean;
  LeftNum: Int64;
  RightIs: Boolean;
  RightNum: Int64;
begin
  LeftIs := ExtrairNumero(Left.Nome, LeftNum);
  RightIs := ExtrairNumero(Right.Nome, RightNum);

  if LeftIs and not RightIs then
    Result := -1
  else
  if not LeftIs and RightIs then
    Result := 1
  else
  if LeftIs and RightIs then
    Result := Min(Max(LeftNum - RightNum, Low(Integer)), High(Integer))
  else
  begin
    if Left.Nome = Right.Nome then
      Result := 0
    else
    if LowerCase(Left.Nome) < LowerCase(Right.Nome) then
      Result := -1
    else
      Result := 1;
  end;
end;

procedure Ordenar(var Itens: TItens);
begin
  TArray.Sort<TItem>(
    Itens,
    TComparer<TItem>.Construct(
      function(const Left, Right: TItem): Integer
      begin
        if Left.Tipo = Right.Tipo then
          Result := Compara(Left, Right)
        else
        if Left.Tipo = TTipoItem.Pasta then
          Result := -1
        else
          Result := 1;
      end
    )
  );
end;

end.

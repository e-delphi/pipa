// Eduardo - 04/11/2024
unit Pipa.Tipos;

interface

type
  TTipoItem = (Pasta, Arquivo);

  TPasta = TArray<String>;

  THPasta = record helper for TPasta
    function ToString: String;
    function Combine(sPasta: String): TPasta;
    function Parent: TPasta;
  end;

  TItem = record
    Tipo: TTipoItem;
    Pasta: TPasta;
    Nome: String;
    Tamanho: Int64;
  end;

  TItens = TArray<TItem>;

implementation

uses
  System.SysUtils,
  System.IOUtils;

{ THPasta }

function THPasta.ToString: String;
begin
  Result := EmptyStr;
  for var Item in Self do
    if Result.IsEmpty then
      Result := Item
    else
      Result := Result + TPath.DirectorySeparatorChar + Item;
end;

function THPasta.Combine(sPasta: String): TPasta;
begin
  Result := Self + [sPasta];
end;

function THPasta.Parent: TPasta;
begin
  Result := Copy(Self, 0, Pred(Length(Self)))
end;

end.

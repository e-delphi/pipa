// Eduardo - 04/11/2024
unit Pipa.Tipos;

interface

type
  TTipoItem = (Pasta, Arquivo);

  TItem = record
    id: Integer;
    tipo: TTipoItem;
    pasta_id: Integer;
    caminho: String;
    nome: String;
    extensao: String;
    tamanho: Double;
    criado: TDateTime;
    modificado: TDateTime;
  end;

  TItens = TArray<TItem>;

implementation

end.

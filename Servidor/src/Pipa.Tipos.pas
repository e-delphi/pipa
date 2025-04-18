// Eduardo - 09/11/2024
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

  TDetalheItem = record
    Criacao: TDateTime;
    UltimoAcesso: TDateTime;
    UltimaAlteracao: TDateTime;
  end;

  TIcon = record
    name: String;
    fileExtensions: TArray<String>;
    fileNames: TArray<String>;
  end;

implementation

end.

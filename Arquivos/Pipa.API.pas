// Eduardo - 05/11/2024
unit Pipa.API;

interface

uses
  System.SysUtils,
  REST.API,
  System.Classes,
  System.JSON,
  System.JSON.Serializers,
  System.NetEncoding,
  System.StrUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.UITypes,
  Pipa.Tipos;

type
  TPipa = class
  private
    FAPI: TRESTAPI;
    FIcons: TDictionary<String, String>;
    function JSONParaItens(aJSON: TJSONArray): TArray<TItem>;
  public
    constructor Create;
    destructor Destroy; override;
    function Listar(sPasta: String = ''): TItens;
    procedure NovaPasta(sPasta, sNome: String);
    procedure Enviar(sArquivoOrigem, sPastaDestino: String);
    function Receber(sPasta, sArquivo: String): TStringStream;
    procedure ExcluirArquivo(sPasta, sArquivo: String);
    procedure ExcluirPasta(sPasta: String);
    // falta renomear arquivo e renomear pasta
    function Icone(Item: TItem): String;
    function Miniatura(Item: TItem): TBytes;
  end;

implementation

uses
  System.Threading,
  Pipa.Ordenacao,
  Pipa.Miniatura;
 
const
  BASEURL = 'http://100.91.113.91:500/';

{ TPipa }

constructor TPipa.Create;
begin
  FAPI := TRESTAPI.Create;
  FAPI.Host(BASEURL);
  FIcons := TDictionary<String, String>.Create;
end;

destructor TPipa.Destroy;
begin
  FreeAndNil(FAPI);
  FreeAndNil(FIcons);
  inherited;
end;

function TPipa.JSONParaItens(aJSON: TJSONArray): TArray<TItem>;
var
  js: TJsonSerializer;
begin
  js := TJsonSerializer.Create;
  try
    Result := js.Deserialize<TArray<TItem>>(aJSON.ToJSON);
  finally
    FreeAndNil(js);
  end;
end;

function TPipa.Listar(sPasta: String = ''): TItens;
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('pasta');

  if not sPasta.IsEmpty then
    FAPI.Query(
      TJSONObject.Create
        .AddPair('separador', TPath.DirectorySeparatorChar)
        .AddPair('pasta', sPasta)
    );

  FAPI.GET;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);

  Result := JSONParaItens(FAPI.Response.ToJSONArray);

  Ordenar(Result);
end;

procedure TPipa.NovaPasta(sPasta, sNome: String);
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('pasta');

  FAPI.Query(
    TJSONObject.Create
      .AddPair('separador', TPath.DirectorySeparatorChar)
      .AddPair('pasta', sPasta)
  );

  FAPI.Body(
    TJSONObject.Create
      .AddPair('nome', sNome)
  );

  FAPI.PUT;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);
end;

procedure TPipa.Enviar(sArquivoOrigem, sPastaDestino: String);
var
  ss: TStringStream;
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('arquivo');

  FAPI.Headers(
    TJSONObject.Create
      .AddPair('Content-Type', 'application/octet-stream')
  );

  FAPI.Query(
    TJSONObject.Create
      .AddPair('separador', TPath.DirectorySeparatorChar)
      .AddPair('pasta', sPastaDestino)
      .AddPair('nome', ExtractFileName(sArquivoOrigem))
  );

  ss := TStringStream.Create;
  try
    ss.LoadFromFile(sArquivoOrigem);
    FAPI.Body(ss);
  except
    begin
      FreeAndNil(ss);
      raise;
    end;
  end;

  FAPI.PUT;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);
end;

function TPipa.Receber(sPasta, sArquivo: String): TStringStream;
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('arquivo');

  FAPI.Query(
    TJSONObject.Create
      .AddPair('separador', TPath.DirectorySeparatorChar)
      .AddPair('pasta', sPasta)
      .AddPair('nome', sArquivo)
  );

  FAPI.GET;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);

  Result := TStringStream.Create;
  FAPI.Response.ToStream.SaveToStream(Result);
  Result.Position := 0;
end;

procedure TPipa.ExcluirArquivo(sPasta, sArquivo: String);
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('arquivo');

  FAPI.Query(
    TJSONObject.Create
      .AddPair('separador', TPath.DirectorySeparatorChar)
      .AddPair('pasta', sPasta)
      .AddPair('nome', sArquivo)
  );

  FAPI.DELETE;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);
end;

procedure TPipa.ExcluirPasta(sPasta: String);
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('pasta');

  FAPI.Query(
    TJSONObject.Create
      .AddPair('separador', TPath.DirectorySeparatorChar)
      .AddPair('pasta', sPasta)
  );

  FAPI.DELETE;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);
end;

function TPipa.Icone(Item: TItem): String;
begin
  if ((Item.Tipo = TTipoItem.Pasta) and FIcons.TryGetValue('', Result)) or FIcons.TryGetValue(ExtractFileExt(Item.Nome), Result) then
    Exit;

  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('icone');

  FAPI.Query(
    TJSONObject.Create
      .AddPair('separador', TPath.DirectorySeparatorChar)
      .AddPair('pasta', Item.Pasta.ToString)
      .AddPair('nome', Item.Nome)
  );

  FAPI.GET;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);

  Result := FAPI.Response.ToStream.DataString;

  if Item.Tipo = TTipoItem.Pasta then
    FIcons.Add('', Result)
  else
    FIcons.Add(ExtractFileExt(Item.Nome), Result);
end;

function TPipa.Miniatura(Item: TItem): TBytes;
var
  sArquivo: String;
  sRaiz: String;
  I: Integer;
begin
  Result := [];

  sRaiz := TPath.Combine(TPath.GetCachePath, 'pipa');
  if not TDirectory.Exists(sRaiz) then
    TDirectory.CreateDirectory(sRaiz);
  sRaiz := TPath.Combine(sRaiz, Item.Pasta.ToString);
  sArquivo := TPath.Combine(sRaiz, Item.Nome);

  if not TFile.Exists(sArquivo) then
  begin  
    TMonitor.Enter(ListaPendenteDownload);
    try
      for I := 0 to Pred(ListaPendenteDownload.Count) do
        if (ListaPendenteDownload[I].Tipo = Item.Tipo) and (ListaPendenteDownload[I].Pasta.ToString = Item.Pasta.ToString) and (ListaPendenteDownload[I].Nome = Item.Nome) then
          Exit;
      
      ListaPendenteDownload.Add(Item);
    finally
      TMonitor.Exit(ListaPendenteDownload);
    end;
    
    Exit;
  end;

  Result := TFile.ReadAllBytes(sArquivo);
end;

end.

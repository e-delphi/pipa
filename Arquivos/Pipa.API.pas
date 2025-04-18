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
    function Listar(iID: Integer = 0): TItens;
    procedure NovaPasta(sPasta, sNome: String);
    procedure Enviar(sArquivoOrigem, sPastaDestino: String);
    function Receber(ID: Integer): TStringStream;
    procedure ExcluirArquivo(ID: Integer);
    procedure ExcluirPasta(ID: Integer);
    // falta renomear arquivo e renomear pasta
    function Icone(Item: TItem): String;
    function Miniatura(Item: TItem): TBytes;
    procedure Atualizar;
  end;

implementation

uses
  System.Threading,
  Pipa.Miniatura,
  Pipa.Constantes;
 
{ TPipa }

constructor TPipa.Create;
begin
  FAPI := TRESTAPI.Create;
  FAPI.Host(HOSTAPI);
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

function TPipa.Listar(iID: Integer = 0): TItens;
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('pasta');

  FAPI.Query(TJSONObject.Create.AddPair('id', iID));

  FAPI.GET;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);

  Result := JSONParaItens(FAPI.Response.ToJSONArray);
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

function TPipa.Receber(ID: Integer): TStringStream;
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('arquivo');

  FAPI.Query(TJSONObject.Create.AddPair('id', ID));

  FAPI.GET;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);

  Result := TStringStream.Create;
  FAPI.Response.ToStream.SaveToStream(Result);
  Result.Position := 0;
end;

procedure TPipa.ExcluirArquivo(ID: Integer);
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('arquivo');

  FAPI.Query(TJSONObject.Create.AddPair('id', ID));

  FAPI.DELETE;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);
end;

procedure TPipa.ExcluirPasta(ID: Integer);
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('pasta');

  FAPI.Query(TJSONObject.Create.AddPair('id', ID));

  FAPI.DELETE;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);
end;

function TPipa.Icone(Item: TItem): String;
begin
  if FIcons.TryGetValue(Item.extensao, Result) then
    Exit;

  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;

  FAPI.Route('icone');

  FAPI.Query(
    TJSONObject.Create
      .AddPair('extensao', Item.nome)
      .AddPair('extensao', Item.extensao)
  );

  FAPI.GET;

  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);

  Result := FAPI.Response.ToStream.DataString;

  FIcons.Add(Item.extensao, Result);
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
  sArquivo := TPath.Combine(sRaiz, Item.id.ToString +'.'+ Item.extensao);

  if not TFile.Exists(sArquivo) then
  begin  
    TMonitor.Enter(ListaPendenteDownload);
    try
      for I := 0 to Pred(ListaPendenteDownload.Count) do
        if ListaPendenteDownload[I].ID = Item.ID then
          Exit;
      
      ListaPendenteDownload.Add(Item);
    finally
      TMonitor.Exit(ListaPendenteDownload);
    end;
    
    Exit;
  end;

  Result := TFile.ReadAllBytes(sArquivo);
end;

procedure TPipa.Atualizar;
begin
  FAPI.Headers.Clear;
  FAPI.Query.Clear;
  FAPI.Body.Clear;
  FAPI.Params.Clear;
  FAPI.Route('atualizar');
  FAPI.GET;
  if FAPI.Response.Status <> TResponseStatus.Sucess then
    raise Exception.Create(FAPI.Response.ToString);
end;

end.

// Eduardo - 09/11/2024
unit Pipa.Arquivos;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.JSON.Serializers,
  System.JSON,
  Horse,
  Pipa.Tipos;

//function NovoItem(const Path: String; const Tipo: TTipoItem; const SearchRec: TSearchRec): TItem;
//function ListarRecursivo(const Path: string): TArray<TItem>;
//function ListarNaoRecursivo(const Path: string): TArray<TItem>;
//function RemoverRaiz(const sRaiz: String; const Itens: TArray<TItem>): TArray<TItem>;
function IDArquivo(ID: Integer): String;
function ItensParaJSON(Itens: TArray<TItem>): TJSONArray;
function DumpBin(sFileName: String): Boolean;
function ForceCombine(sEsquerda, sDireita: String): String;
function ConcatenaQuery(Req: THorseRequest): String;
function Icones: TArray<TIcon>;
function Miniatura(ID: Integer): TStringStream;
function Pasta(iID: Integer): TJSONArray;

implementation

uses
  Winapi.ShellApi,
  Winapi.ActiveX,
  System.Types,
  System.StrUtils,
  System.Math,
  System.DateUtils,
  System.IOUtils,
  System.NetEncoding,
  System.Hash,
  System.Math.Vectors,
  System.UITypes,
  FMX.Types,
  FMX.Graphics,
  FMX.Surfaces,
  Pipa.Constantes,
  SQLite,
  Data.DB,
  System.Generics.Collections,
  System.Generics.Defaults,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  CCR.Exif,
  Pipa.Fotos;

//function NovoItem(const Path: String; const Tipo: TTipoItem; const SearchRec: TSearchRec): TItem;
//begin
//  Result := Default(TItem);
//  Result.Tipo := Tipo;
//  Result.Pasta := Path.Split([TPath.DirectorySeparatorChar]);
//  Result.Nome := SearchRec.Name;
//  Result.Tamanho := SearchRec.Size;
//end;
//
//function ListarRecursivo(const Path: string): TArray<TItem>;
//var
//  SearchRec: TSearchRec;
//begin
//  Result := [];
//  if FindFirst(TPath.Combine(Path, '*', False), faAnyFile, SearchRec) = 0 then
//  try
//    repeat
//      if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
//        Continue;
//
//      if (SearchRec.Attr and System.SysUtils.faDirectory <> 0) then
//        Result := Result + [NovoItem(Path, TTipoItem.Pasta, SearchRec)] + ListarRecursivo(TPath.Combine(Path, SearchRec.Name, False))
//      else
//        Result := Result + [NovoItem(Path, TTipoItem.Arquivo, SearchRec)];
//    until FindNext(SearchRec) <> 0;
//  finally
//    FindClose(SearchRec);
//  end;
//end;
//
//function ListarNaoRecursivo(const Path: string): TArray<TItem>;
//var
//  SearchRec: TSearchRec;
//begin
//  Result := [];
//  if FindFirst(TPath.Combine(Path, '*', False), faAnyFile, SearchRec) = 0 then
//  try
//    repeat
//      if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
//        Continue;
//
//      if MatchStr(SearchRec.Name, IGNORAR) then
//        Continue;
//
//      if (SearchRec.Attr and System.SysUtils.faDirectory <> 0) then
//        Result := Result + [NovoItem(Path, TTipoItem.Pasta, SearchRec)]
//      else
//        Result := Result + [NovoItem(Path, TTipoItem.Arquivo, SearchRec)];
//    until FindNext(SearchRec) <> 0;
//  finally
//    FindClose(SearchRec);
//  end;
//end;
//
//function RemoverRaiz(const sRaiz: String; const Itens: TArray<TItem>): TArray<TItem>;
//var
//  I: Integer;
//  iRaiz: Integer;
//begin
//  Result := Itens;
//  iRaiz := Length(sRaiz.Split([TPath.DirectorySeparatorChar]));
//  for I := Low(Result) to High(Result) do
//    Result[I].Pasta := Copy(Result[I].Pasta, iRaiz);
//end;

function IDArquivo(ID: Integer): String;
var
  Inst: IConnection;
begin
  Inst := TPool.Instance;
  Inst.Query.Open(
    sl +'with recursive pasta_cte as '+
    sl +'( '+
    sl +'    select id '+
    sl +'         , pasta_id '+
    sl +'         , nome '+
    sl +'         , nome as caminho '+
    sl +'      from pasta '+
    sl +'     where pasta_id is null '+
    sl +'     union all '+
    sl +'    select p.id '+
    sl +'         , p.pasta_id '+
    sl +'         , p.nome '+
    sl +'         , pc.caminho || ''\'' || p.nome as caminho '+
    sl +'      from pasta p '+
    sl +'      join pasta_cte pc '+
    sl +'        on pc.id = p.pasta_id '+
    sl +') '+
    sl +'select iif(pc.caminho is null, '''', pc.caminho || ''\'') || a.nome || ''.'' || a.extensao as arquivo '+
    sl +'  from arquivo as a '+
    sl +'  left '+
    sl +'  join pasta_cte as pc '+
    sl +'    on pc.id = a.pasta_id '+
    sl +' where a.id = '+ ID.ToString
  );
  Result := ForceCombine(RAIZ, Inst.Query.FieldByName('arquivo').AsString);
end;

function ItensParaJSON(Itens: TArray<TItem>): TJSONArray;
var
  js: TJsonSerializer;
begin
  js := TJsonSerializer.Create;
  try
    Result := TJSONObject.ParseJSONValue(js.Serialize<TArray<TItem>>(Itens)) as TJSONArray;
  finally
    FreeAndNil(js);
  end;
end;

function DumpBin(sFileName: String): Boolean;
var
  fos: TSHFileOpStruct;
begin
  FillChar(fos, SizeOf(fos), 0);
  with fos do
  begin
    wFunc := FO_DELETE;
    pFrom := PChar(sFileName + #0);
    fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_SILENT;
  end;
  Result := ShFileOperation(fos) = 0;
end;

function ForceCombine(sEsquerda, sDireita: String): String;
var
  sItem: String;
  sTemp: String;
begin
  sTemp := EmptyStr;
  for sItem in sDireita.Split([TPath.DirectorySeparatorChar]) do
    if not sItem.IsEmpty then
      if sTemp.IsEmpty then
        sTemp := sItem
      else
        sTemp := sTemp + TPath.DirectorySeparatorChar + sItem;

  Result := TPath.Combine(sEsquerda, sDireita);
end;

function ConcatenaQuery(Req: THorseRequest): String;
var
  sSeparador: String;
  sPasta: String;
begin
  sSeparador := Req.Query.Items['separador'];
  sPasta := Req.Query.Items['pasta'];

  sPasta := sPasta.Replace(sSeparador, TPath.DirectorySeparatorChar);

  Result := ForceCombine(RAIZ, sPasta);
end;

function Pasta(iID: Integer): TJSONArray;
var
  Inst: IConnection;
  oItem: TJSONObject;
begin
  Inst := TPool.Instance;
  Inst.Query.Open(
    sl +'with recursive pasta_cte as '+
    sl +'( '+
    sl +'    select id '+
    sl +'         , pasta_id '+
    sl +'         , nome '+
    sl +'         , nome as caminho '+
    sl +'      from pasta '+
    sl +'     where pasta_id is null '+
    sl +'     union all '+
    sl +'    select p.id '+
    sl +'         , p.pasta_id '+
    sl +'         , p.nome '+
    sl +'         , pc.caminho || ''\'' || p.nome as caminho '+
    sl +'      from pasta p '+
    sl +'      join pasta_cte pc '+
    sl +'        on pc.id = p.pasta_id '+
    sl +') '+
    sl +'select p.id '+
    sl +'     , 0 as tipo '+
    sl +'     , p.pasta_id '+
    sl +'     , case '+
    sl +'       when cte.caminho = p.nome then ''\'' '+
    sl +'       else substr(cte.caminho, length(cte.caminho) - length(p.nome) - 1) '+
    sl +'        end as caminho '+
    sl +'     , p.nome '+
    sl +'     , null as extensao '+
    sl +'     , null as tamanho '+
    sl +'     , null as "criado::DATETIME" '+
    sl +'     , null as "modificado::DATETIME" '+
    sl +'  from pasta as p '+
    sl +'  left '+
    sl +'  join pasta_cte as cte '+
    sl +'    on cte.id = p.id '+
    sl +' where ifnull(p.pasta_id, 0) = '+ iID.ToString +
    sl +' union '+
    sl +'select a.id '+
    sl +'     , 1 as tipo '+
    sl +'     , a.pasta_id '+
    sl +'     , ifnull(cte.caminho, ''\'') as caminho '+
    sl +'     , a.nome '+
    sl +'     , a.extensao '+
    sl +'     , a.tamanho '+
    sl +'     , a.criado as "criado::DATETIME" '+
    sl +'     , a.modificado as "modificado::DATETIME" '+
    sl +'  from arquivo as a '+
    sl +'  left '+
    sl +'  join pasta_cte as cte '+
    sl +'    on cte.id = a.pasta_id '+
    sl +' where ifnull(a.pasta_id, 0) = '+ iID.ToString +
    sl +' order '+
    sl +'    by tipo '+
    sl +'     , criado desc '+
    sl +'     , a.nome '
  );

  Result := TJSONArray.Create;
  while not Inst.Query.Eof do
  begin
    oItem := TJSONObject.Create;
    oItem.AddPair('id', Inst.Query.FieldByName('id').AsInteger);
    oItem.AddPair('tipo', Inst.Query.FieldByName('tipo').AsInteger);
    oItem.AddPair('pasta_id', Inst.Query.FieldByName('pasta_id').AsInteger);
    oItem.AddPair('caminho', Inst.Query.FieldByName('caminho').AsString);
    oItem.AddPair('nome', Inst.Query.FieldByName('nome').AsString);
    oItem.AddPair('extensao', Inst.Query.FieldByName('extensao').AsString);
    oItem.AddPair('tamanho', Inst.Query.FieldByName('tamanho').AsString);

    if Inst.Query.FieldByName('criado').IsNull then
      oItem.AddPair('criado', TJSONNull.Create)
    else
      oItem.AddPair('criado', DateToISO8601(Inst.Query.FieldByName('criado').AsDateTime));

    if Inst.Query.FieldByName('modificado').IsNull then
      oItem.AddPair('modificado', TJSONNull.Create)
    else
      oItem.AddPair('modificado', DateToISO8601(Inst.Query.FieldByName('modificado').AsDateTime));

    Result.Add(oItem);

    Inst.Query.Next;
  end;
end;

var
  M: TMREWSync;

function Miniatura(ID: Integer): TStringStream;
var
  Inst: IConnection;
  Width: Single;
  Height: Single;
  sArquivo: String;
begin
  Result := nil;
  M.BeginWrite;
  try
    Inst := TPool.Instance;
    Inst.Query.Open(
      sl +'with recursive pasta_cte as '+
      sl +'( '+
      sl +'    select id '+
      sl +'         , pasta_id '+
      sl +'         , nome '+
      sl +'         , nome as caminho '+
      sl +'      from pasta '+
      sl +'     where pasta_id is null '+
      sl +'     union all '+
      sl +'    select p.id '+
      sl +'         , p.pasta_id '+
      sl +'         , p.nome '+
      sl +'         , pc.caminho || ''\'' || p.nome as caminho '+
      sl +'      from pasta p '+
      sl +'      join pasta_cte pc '+
      sl +'        on pc.id = p.pasta_id '+
      sl +') '+
      sl +'select a.id as arquivo_id '+
      sl +'     , f.id as foto_id '+
      sl +'     , m.id as miniatura_id '+
      sl +'     , iif(pc.caminho is null, '''', pc.caminho) as caminho '+
      sl +'     , a.nome '+
      sl +'     , a.extensao '+
      sl +'     , m.bytes '+
      sl +'  from arquivo as a '+
      sl +'  left '+
      sl +'  join pasta_cte as pc '+
      sl +'    on pc.id = a.pasta_id '+
      sl +'  left '+
      sl +'  join foto as f '+
      sl +'    on f.arquivo_id = a.id '+
      sl +'  left '+
      sl +'  join miniatura as m '+
      sl +'    on m.foto_id = f.id '+
      sl +' where a.id = '+ ID.ToString
    );

    if not Inst.Query.IsEmpty and not Inst.Query.FieldByName('bytes').IsNull then
    begin
      Result := TStringStream.Create;
      TBlobField(Inst.Query.FieldByName('bytes')).SaveToStream(Result);
    end
    else
    begin
      if Inst.Query.IsEmpty then
        raise Exception.Create('Arquivo não encontrado!');

      if Inst.Query.FieldByName('foto_id').IsNull then
        raise Exception.Create('Foto não encontrada!');

      if Inst.Query.FieldByName('miniatura_id').IsNull then
      begin
        CoInitialize(nil);
        try
          sArquivo := TPath.Combine(RAIZ, Inst.Query.FieldByName('caminho').AsString);
          sArquivo := TPath.Combine(sArquivo, Inst.Query.FieldByName('nome').AsString) +'.'+ Inst.Query.FieldByName('extensao').AsString;

          Result := GerarPrevia(sArquivo);

          TamanhoImagem(Result, Width, Height);

          InsertBlobUsingFDCommand(
            Inst.Connection,
            sl +'insert '+
            sl +'  into miniatura '+
            sl +'     ( foto_id '+
            sl +'     , largura '+
            sl +'     , altura '+
            sl +'     , bytes '+
            sl +'     ) '+
            sl +'values '+
            sl +'     ( '+ Inst.Query.FieldByName('foto_id').AsString +
            sl +'     , '+ FloatToJson(Width) +
            sl +'     , '+ FloatToJson(Height) +
            sl +'     , :bytes '+
            sl +'     ); ',
            Result
          );
        finally
          CoUninitialize;
        end;
      end;
    end;
  finally
    M.EndWrite;
  end;
end;

var
  FIcones: TArray<TIcon>;

function Icones: TArray<TIcon>;
begin
  if Length(FIcones) > 0 then
    Exit(FIcones);

  with TJsonSerializer.Create do
  try
    FIcones := Deserialize<TArray<TIcon>>(TFile.ReadAllText('icons\icon.json', System.SysUtils.TEncoding.UTF8));
    Result := FIcones;
  finally
    Free;
  end;
end;

initialization
  M := TMREWSync.Create;

finalization
  FreeAndNil(M);

end.

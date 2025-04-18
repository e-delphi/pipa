// Eduardo - 23/11/2024
unit Pipa.Fotos;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.JSON,
  FireDAC.Comp.Client,
  Horse,
  Pipa.Tipos;

procedure Indexar;
procedure Processar;
function GerarPrevia(sArquivo: String): TStringStream;
procedure TamanhoImagem(const ss: TStringStream; out Width, Height: Single);
procedure InsertBlobUsingFDCommand(AConnection: TFDConnection; ASQL: String; AStream: TStream);

implementation

uses
  Winapi.ShellApi,
  Winapi.ActiveX,
  System.Types,
  System.StrUtils,
  System.Math,
  System.Character,
  System.DateUtils,
  System.IOUtils,
  System.JSON.Serializers,
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
  FireDAC.Stan.Param,
  CCR.Exif;

procedure Indexar2(const Inst: IConnection; const Path: String = ''; const ID: String = 'null');
var
  SearchRec: TSearchRec;
  Info: TDateTimeInfoRec;
  sArquivo: String;
  sCriado: String;
  sModificado: String;
  iUltimoID: Integer;
begin
  try
    try
      if not FindFirst(TPath.Combine(Path, '*', False), faAnyFile, SearchRec) = 0 then
        Exit;
      repeat
        sArquivo := SearchRec.Name;

        if (sArquivo = '.') or (sArquivo = '..') then
          Continue;

        if (SearchRec.Attr and System.SysUtils.faDirectory <> 0) then
        begin
          if MatchStr(sArquivo, IGNORAR) then
            Continue;

          Inst.Query.Open(
            sl +'select id '+
            sl +'  from pasta as p '+
            sl +' where p.pasta_id '+ IfThen(ID = 'null', 'is', '=') +' '+ ID +
            sl +'   and p.nome = '+ sArquivo.QuotedString
          );
          if Inst.Query.IsEmpty then
          begin
            Inst.Connection.ExecSQL(
              sl +'insert '+
              sl +'  into pasta '+
              sl +'     ( pasta_id '+
              sl +'     , nome '+
              sl +'     ) '+
              sl +'values '+
              sl +'     ( '+ ID +
              sl +'     , '+ sArquivo.QuotedString +
              sl +'     ); '
            );

            Inst.Query.Open('select last_insert_rowid() as id');
          end;

          iUltimoID := Inst.Query.FieldByName('id').AsInteger;

          Indexar2(Inst, TPath.Combine(Path, sArquivo, False), iUltimoID.ToString)
        end
        else
        begin
          if FileGetDateTimeInfo(TPath.Combine(Path, sArquivo, False), Info) then
          begin
            sCriado := DateToISO8601(Info.CreationTime).QuotedString;
            sModificado := DateToISO8601(Info.TimeStamp).QuotedString;
          end
          else
          begin
            sCriado := 'null';
            sModificado := 'null';
          end;

          Inst.Query.Open(
            sl +'select id '+
            sl +'     , tamanho as "tamanho::INT64" '+
            sl +'     , ifnull(criado, ''null'') as criado '+
            sl +'     , ifnull(modificado, ''null'') as modificado '+
            sl +'  from arquivo as a '+
            sl +' where a.pasta_id '+ IfThen(ID = 'null', 'is', '=') +' '+ ID +
            sl +'   and a.nome = '+ ChangeFileExt(sArquivo, EmptyStr).QuotedString +
            sl +'   and a.extensao = '+ ExtractFileExt(sArquivo).ToLower.Replace('.', EmptyStr).QuotedString
          );
          if Inst.Query.IsEmpty then
          begin
            Inst.Connection.ExecSQL(
              sl +'insert '+
              sl +'  into arquivo '+
              sl +'     ( pasta_id '+
              sl +'     , nome '+
              sl +'     , extensao '+
              sl +'     , tamanho '+
              sl +'     , criado '+
              sl +'     , modificado '+
              sl +'     ) '+
              sl +'values '+
              sl +'     ( '+ ID +
              sl +'     , '+ ChangeFileExt(sArquivo, EmptyStr).QuotedString +
              sl +'     , '+ ExtractFileExt(sArquivo).ToLower.Replace('.', EmptyStr).QuotedString +
              sl +'     , '+ SearchRec.Size.ToString +
              sl +'     , '+ sCriado +
              sl +'     , '+ sModificado +
              sl +'     ) '
            );
          end
          else
          begin
            if (Inst.Query.FieldByName('tamanho').AsExtended  <> SearchRec.Size) or
               (Inst.Query.FieldByName('criado').AsString     <> sCriado.Replace('''', '')) or
               (Inst.Query.FieldByName('modificado').AsString <> sModificado.Replace('''', '')) then
            begin
              Inst.Connection.ExecSQL(
                sl +'delete '+
                sl +'  from miniatura '+
                sl +' where id in ( select m.id '+
                sl +'                 from miniatura as m '+
                sl +'                inner '+
                sl +'                 join foto as f '+
                sl +'                   on f.id = m.id '+
                sl +'                where f.arquivo_id = '+ Inst.Query.FieldByName('id').AsString +
                sl +'             ); '+
                sl +
                sl +'delete '+
                sl +'  from foto '+
                sl +' where arquivo_id = '+ Inst.Query.FieldByName('id').AsString +';'+
                sl +
                sl +'update arquivo '+
                sl +'   set tamanho    = '+ SearchRec.Size.ToString +
                sl +'     , criado     = '+ sCriado +
                sl +'     , modificado = '+ sModificado +
                sl +' where id = '+ Inst.Query.FieldByName('id').AsString
              );
            end;
          end;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  except on E: Exception do
    raise Exception.Create('Arquivo: '+ TPath.Combine(Path, sArquivo, False) + sl + E.Message);
  end;
end;

procedure Indexar;
var
  Inst: IConnection;
begin
  Inst := TPool.Instance;
  Inst.Connection.StartTransaction;
  try
    // remove arquivos do banco que não existem no disco
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
      sl +'select a.id '+
      sl +'     , iif(pc.caminho is null, '''', pc.caminho || ''\'') || a.nome || ''.'' || a.extensao as arquivo '+
      sl +'     , a.tamanho '+
      sl +'     , a.criado '+
      sl +'     , a.modificado  '+
      sl +'  from arquivo as a '+
      sl +'  left '+
      sl +'  join pasta_cte as pc '+
      sl +'    on pc.id = a.pasta_id '
    );
    Inst.Query.First;
    while not Inst.Query.Eof do
    begin
      if not TFile.Exists(TPath.Combine(RAIZ, Inst.Query.FieldByName('arquivo').AsString)) then
      try
        Inst.Connection.ExecSQL(
          sl +'delete '+
          sl +'  from miniatura '+
          sl +' where foto_id in ( select f.id '+
          sl +'                      from foto as f '+
          sl +'                     where f.arquivo_id = '+ Inst.Query.FieldByName('id').AsString +
          sl +'                  ); '
        );

        Inst.Connection.ExecSQL(
          sl +'delete '+
          sl +'  from foto '+
          sl +' where arquivo_id = '+ Inst.Query.FieldByName('id').AsString +';'
        );

        Inst.Connection.ExecSQL(
          sl +'delete '+
          sl +'  from arquivo '+
          sl +' where id = '+ Inst.Query.FieldByName('id').AsString +';'
        );
      except on E: Exception do
        raise Exception.Create('Arquivo: '+ Inst.Query.FieldByName('id').AsString + sl + E.Message);
      end;
      Inst.Query.Next;
    end;

    // remove pastas do banco que não existem mais no disco
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
      sl +'select id '+
      sl +'     , caminho '+
      sl +'  from pasta_cte as pc '+
      sl +' order '+
      sl +'    by length(caminho) desc '
    );
    Inst.Query.First;
    while not Inst.Query.Eof do
    begin
      if not TDirectory.Exists(TPath.Combine(RAIZ, Inst.Query.FieldByName('caminho').AsString)) then
        Inst.Connection.ExecSQL(
          sl +'delete '+
          sl +'  from pasta '+
          sl +' where id = '+ Inst.Query.FieldByName('id').AsString
        );
      Inst.Query.Next;
    end;

    // se não tem nunhum arquivo nem nenhuma pasta, redefine os id's
    if Inst.Connection.ExecSQLScalar(
      sl +'select count(a.id) + count(p.id) as quantidade '+
      sl +'  from arquivo as a '+
      sl +'     , pasta as p ') = 0 then
    begin
      Inst.Connection.ExecSQL(
        sl +'delete from miniatura; '+
        sl +'delete from foto; '+
        sl +'delete from arquivo; '+
        sl +'delete from pasta; '+
        sl +'delete from sqlite_sequence where name = ''miniatura''; '+
        sl +'delete from sqlite_sequence where name = ''foto''; '+
        sl +'delete from sqlite_sequence where name = ''arquivo''; '+
        sl +'delete from sqlite_sequence where name = ''pasta''; '
      );
    end;

    CoInitialize(nil);
    try
      Indexar2(Inst, RAIZ);
    finally
      CoUninitialize;
    end;

    Inst.Connection.Commit;
  except
    Inst.Connection.Rollback;
    raise;
  end;
end;

procedure InsertBlobUsingFDCommand(AConnection: TFDConnection; ASQL: String; AStream: TStream);
var
  FDCommand: TFDCommand;
begin
  FDCommand := TFDCommand.Create(nil);
  try
    FDCommand.Connection := AConnection;
    FDCommand.CommandText.Text := ASQL;
    FDCommand.Params[0].DataType := ftBlob;
    FDCommand.Params[0].LoadFromStream(AStream, ftBlob);
    FDCommand.Execute;
  finally
    FDCommand.Free;
  end;
end;

function ISONull(Value: TISOSpeedRatings): String;
begin
  Result := Value.ToString;
  if Result.IsEmpty then
    Result := 'null';    
end;

function FloatNull(Value: Double): String;
begin
  if IsNan(Value) then
    Result := 'null'
  else
    Result := FloatToJson(Value);
end;

function ModeloCamera(Value: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(Value) do
    if Value[I].IsLetterOrDigit or
       Value[I].IsWhiteSpace or
       Value[I].IsPunctuation or
       Value[I].IsSeparator or
       Value[I].IsWhiteSpace then
      Result := Result + Value[I]
    else
      Result := Result + ' ';
end;

function GetProportionalSize(const OriginalWidth, OriginalHeight, MaxWidth, MaxHeight: Single): TSizeF;
var
  Ratio: Single;
begin
  if (OriginalWidth > MaxWidth) or (OriginalHeight > MaxHeight) then
  begin
    Ratio := Min(MaxWidth / OriginalWidth, MaxHeight / OriginalHeight);
    Result := TSizeF.Create(OriginalWidth * Ratio, OriginalHeight * Ratio);
  end
  else
  begin
    Result := TSizeF.Create(OriginalWidth, OriginalHeight);
  end;
end;

procedure ResizeBitmap(const Source: TBitmap; const MaxWidth, MaxHeight: Single; out ResizedBitmap: TBitmap);
var
  ProportionalSize: TSizeF;
  TargetRect: TRectF;
begin
  ProportionalSize := GetProportionalSize(Source.Width, Source.Height, MaxWidth, MaxHeight);
  ResizedBitmap := TBitmap.Create(Round(ProportionalSize.Width), Round(ProportionalSize.Height));
  TargetRect := TRectF.Create(0, 0, ProportionalSize.Width, ProportionalSize.Height);
  ResizedBitmap.Canvas.BeginScene;
  try
    ResizedBitmap.Canvas.DrawBitmap(Source, Source.BoundsF, TargetRect, 1, False);
  finally
    ResizedBitmap.Canvas.EndScene;
  end;
end;

function GerarPrevia(sArquivo: String): TStringStream;
var
  bmp: TBitmap;
  bmp2: TBitmap;
  Surface: TBitmapSurface;
  Params: TBitmapCodecSaveParams;
begin
  bmp := TBitmap.Create;
  bmp2 := TBitmap.Create;
  try
    bmp.LoadFromFile(sArquivo);
    ResizeBitmap(bmp, 100, 100, bmp2);

    Surface := TBitmapSurface.Create;
    try
      Surface.Assign(bmp2);
      Result := TStringStream.Create;
      Params.Quality := 80;
      TBitmapCodecManager.SaveToStream(Result, Surface, '.jpg', @Params);
    finally
      Surface.Free;
    end;
  finally
    FreeAndNil(bmp);
    FreeAndNil(bmp2);
  end;
end;

procedure TamanhoImagem(const ss: TStringStream; out Width, Height: Single);
var
  bmp: TBitmap;
begin
  try
    bmp := TBitmap.Create;
    try
      bmp.LoadFromStream(ss);
      Width := bmp.Width;
      Height := bmp.Height;
    finally
      FreeAndNil(bmp);
    end; 
  except 
    Width := -1;
    Height := -1;          
  end;
end;

procedure TamanhoImagemArquivo(const Arquivo: String; out Width, Height: Single);
var  
  ss: TStringStream;
begin
  ss := TStringStream.Create;
  try
    ss.LoadFromFile(Arquivo);
    TamanhoImagem(ss, Width, Height);
  finally
    FreeAndNil(ss);
  end;
end;

procedure Processar;
var
  Inst: IConnection;
  sArquivo: String;
  Exif: TExifData;
  sCoordenadas: String;
  sAltitude: String;
  bmp: TBitmap;
  ss: TStringStream;
  iUltimoID: Integer;
  Width: Single;
  Height: Single;
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
    sl +'select a.id '+
    sl +'     , iif(pc.caminho is null, '''', pc.caminho || ''\'') || a.nome || ''.'' || a.extensao as arquivo '+
    sl +'     , a.criado '+
    sl +'  from arquivo as a '+
    sl +'  left '+
    sl +'  join pasta_cte as pc '+
    sl +'    on pc.id = a.pasta_id '+
    sl +'  left '+
    sl +'  join foto as f '+
    sl +'    on f.arquivo_id = a.id '+
    sl +' where lower(a.extensao) in (''jpg'', ''bmp'', ''png'') '+
    sl +'   and f.id is null '
  );
  CoInitialize(nil);
  try
    Inst.Query.First;
    while not Inst.Query.Eof do
    begin
      sArquivo := TPath.Combine(RAIZ, Inst.Query.FieldByName('arquivo').AsString, False);

      Exif := TExifData.Create(nil);
      try
        Exif.LoadFromGraphic(sArquivo);

        if Exif.Empty then
        begin
          TamanhoImagemArquivo(sArquivo, Width, Height);
          
          iUltimoID := Inst.Connection.ExecSQLScalar(
            sl +'insert '+
            sl +'  into foto '+
            sl +'     ( arquivo_id '+
            sl +'     , tirada '+
            sl +'     , camera '+
            sl +'     , f '+
            sl +'     , exposicao '+
            sl +'     , distancia_focal '+
            sl +'     , iso '+
            sl +'     , megapixels '+
            sl +'     , largura '+
            sl +'     , altura '+
            sl +'     , coordenadas '+
            sl +'     , altitude '+
            sl +'     , flash '+
            sl +'     ) '+
            sl +'values '+
            sl +'     ( '+ Inst.Query.FieldByName('id').AsString +
            sl +'     , '+ Inst.Query.FieldByName('criado').AsString.QuotedString +
            sl +'     , null '+
            sl +'     , null '+
            sl +'     , null '+
            sl +'     , null '+
            sl +'     , null '+
            sl +'     , null '+
            sl +'     , '+ FloatNull(Width) +
            sl +'     , '+ FloatNull(Height) +
            sl +'     , null '+
            sl +'     , null '+
            sl +'     , null '+
            sl +'     ); '+
            sl +
            sl +'select last_insert_rowid() as id '
          );

          try
            ss := GerarPrevia(sArquivo);
            try
              TamanhoImagem(ss, Width, Height);
            
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
                sl +'     ( '+ iUltimoID.ToString +
                sl +'     , '+ FloatToJson(Width) +
                sl +'     , '+ FloatToJson(Height) +
                sl +'     , :bytes '+
                sl +'     ); ',
                ss
              );
            finally
              FreeAndNil(ss);
            end;
          except
          end;
        end
        else
        begin
          sCoordenadas := 'null';
          sAltitude := 'null';
          if not Exif.GPSLatitude.AsString.IsEmpty then
          begin
            sCoordenadas :=
              Exif.GPSLatitude.Degrees.ToString +'°'+
              Exif.GPSLatitude.Minutes.ToString +''''+
              FormatFloat('.#', (Exif.GPSLatitude.Seconds.Numerator / Exif.GPSLatitude.Seconds.Denominator)).Replace(',', '.') +'"'+
              IfThen(Exif.GPSLatitude.Direction = ltSouth, 'S', 'N') +
              ' '+
              Exif.GPSLongitude.Degrees.ToString +'°'+
              Exif.GPSLongitude.Minutes.ToString +''''+
              FormatFloat('.#', (Exif.GPSLongitude.Seconds.Numerator / Exif.GPSLongitude.Seconds.Denominator)).Replace(',', '.') +'"'+
              IfThen(Exif.GPSLongitude.Direction = lnWest, 'W', 'E');

            sCoordenadas := sCoordenadas.QuotedString;
            sAltitude := FloatNull(Exif.GPSAltitude.Numerator / Exif.GPSAltitude.Denominator);
          end;

          iUltimoID := Inst.Connection.ExecSQLScalar(
            sl +'insert '+
            sl +'  into foto '+
            sl +'     ( arquivo_id '+
            sl +'     , tirada '+
            sl +'     , camera '+
            sl +'     , f '+
            sl +'     , exposicao '+
            sl +'     , distancia_focal '+
            sl +'     , iso '+
            sl +'     , megapixels '+
            sl +'     , largura '+
            sl +'     , altura '+
            sl +'     , coordenadas '+
            sl +'     , altitude '+
            sl +'     , flash '+
            sl +'     ) '+
            sl +'values '+
            sl +'     ( '+ Inst.Query.FieldByName('id').AsString +
            sl +'     , '+ DateToISO8601(Exif.DateTimeOriginal.Value).QuotedString +
            sl +'     , '+ ModeloCamera(Exif.CameraModel).QuotedString +
            sl +'     , '+ FloatNull(Exif.FNumber.Numerator / Exif.FNumber.Denominator) +
            sl +'     , '+ FloatNull(Exif.ExposureTime.Denominator / Exif.ExposureTime.Numerator) +
            sl +'     , '+ FloatNull(Exif.FocalLength.Numerator / Exif.FocalLength.Denominator) +
            sl +'     , '+ ISONull(Exif.ISOSpeedRatings) +
            sl +'     , '+ FloatNull(RoundTo((Exif.ExifImageWidth.Value * Exif.ExifImageHeight.Value) / 1000000, -2)) +
            sl +'     , '+ FloatNull(Exif.ExifImageWidth.Value) +
            sl +'     , '+ FloatNull(Exif.ExifImageHeight.Value) +
            sl +'     , '+ sCoordenadas +
            sl +'     , '+ sAltitude +
            sl +'     , '+ IfThen(Exif.Flash.Fired, '1', '0') +
            sl +'     ); '+
            sl +
            sl +'select last_insert_rowid() as id '
          );

          if not Exif.HasThumbnail then
          begin
            bmp := TBitmap.Create;
            try
              bmp.LoadFromFile(sArquivo);
              Exif.CreateThumbnail(bmp);
            finally
              FreeAndNil(bmp);
            end;
          end;

          ss := TStringStream.Create;
          try
            Exif.Thumbnail.SaveToStream(ss);

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
              sl +'     ( '+ iUltimoID.ToString +
              sl +'     , '+ FloatToJson(Exif.Thumbnail.Width) +
              sl +'     , '+ FloatToJson(Exif.Thumbnail.Height) +
              sl +'     , :bytes '+
              sl +'     ); ',
              ss
            );
          finally
            FreeAndNil(ss);
          end;
        end;
      finally
        FreeAndNil(Exif);
      end;
      Inst.Query.Next;
    end;
  finally
    CoUninitialize;
  end;
end;

end.

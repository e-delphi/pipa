program PipaServidor;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.Windows,
  Winapi.ShellApi,
  Winapi.ActiveX,
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.Math,
  System.DateUtils,
  System.IOUtils,
  System.JSON.Serializers,
  System.JSON,
  System.NetEncoding,
  FMX.Graphics,
  FMX.Surfaces,
  Horse,
  Horse.Jhonson,
  Horse.HandleException,
  Horse.CORS,
  Horse.OctetStream,
  Horse.JWT,
  JOSE.Core.JWT,
  JOSE.Core.Builder,
  JOSE.Types.Bytes,
  IdSSLOpenSSL,
  Pipa.Arquivos in 'src\Pipa.Arquivos.pas',
  Pipa.Constantes in 'src\Pipa.Constantes.pas',
  Pipa.Tipos in 'src\Pipa.Tipos.pas',
  SQLite in 'src\SQLite.pas',
  Pipa.Fotos in 'src\Pipa.Fotos.pas',
  Pipa.Migracoes in 'src\Pipa.Migracoes.pas';

begin
  // Habilita caracteres UTF8 no terminal
  SetConsoleOutputCP(CP_UTF8);

  THorse
    .Use(Jhonson)
    .Use(OctetStream)
    .Use(HandleException)
    .Use(CORS);
//    .Use(
//      HorseJWT(
//        JWTKEY,
//        THorseJWTConfig.New
//          .SessionClass(TJWTClaims)
//          .SkipRoutes(['favicon.ico', 'listar'])
//      )
//    );

//  THorse.IOHandleSSL
//    .CertFile('certificado\certificate.crt')
//    .KeyFile('certificado\private.key')
//    .SSLVersions([sslvSSLv2, sslvSSLv23, sslvSSLv3, sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2])
//    .Active(True);

  THorse.Get(
    '/pasta',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send<TJSONArray>(Pipa.Arquivos.Pasta(Req.Query.Items['id'].ToInteger));
    end
  );

//  THorse.Put(
//    '/pasta',
//    procedure(Req: THorseRequest; Res: THorseResponse)
//    var
//      sPasta: String;
//      sNome: String;
//    begin
//      if not PERMITE_INCLUSAO then
//        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');
//
//      sPasta := ConcatenaQuery(Req);
//      sNome := Req.Body<TJSONValue>.GetValue<String>('nome');
//
//      TDirectory.CreateDirectory(ForceCombine(sPasta, sNome));
//    end
//  );
//
//  THorse.Delete(
//    '/pasta',
//    procedure(Req: THorseRequest; Res: THorseResponse)
//    var
//      sPasta: String;
//    begin
//      if not PERMITE_EXCLUSAO then
//        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');
//
//      sPasta := ConcatenaQuery(Req);
//
//      if not TDirectory.Exists(sPasta) then
//        raise EHorseException.New.Status(THTTPStatus.NotFound).Error('Pasta "'+ Req.Query.Items['pasta'] +'" não encontrada!');
//
//      if not DumpBin(sPasta + TPath.DirectorySeparatorChar) then
//        raise EHorseException.New.Status(THTTPStatus.InternalServerError).Error('Erro ao remover a pasta "'+ Req.Query.Items['pasta'] +'"!');
//    end
//  );
//
//  THorse.Put(
//    '/arquivo',
//    procedure(Req: THorseRequest; Res: THorseResponse)
//    var
//      sPasta: String;
//      sNome: String;
//    begin
//      if not PERMITE_INCLUSAO then
//        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');
//
//      sPasta := ConcatenaQuery(Req);
//      sNome := Req.Query.Items['nome'];
//
//      TDirectory.CreateDirectory(sPasta);
//
//      Req.Body<TStringStream>.SaveToFile(ForceCombine(sPasta, sNome));
//    end
//  );

  THorse.Get(
    '/arquivo',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sArquivo: String;
    begin
      sArquivo := IDArquivo(Req.Query.Items['id'].ToInteger);

      if not TFile.Exists(sArquivo) then
        raise EHorseException.New.Status(THTTPStatus.NotFound).Error('Arquivo "'+ Req.Query.Items['nome'] +'" não encontrado!');

      Res.SendFile(sArquivo);
    end
  );

//  THorse.Delete(
//    '/arquivo',
//    procedure(Req: THorseRequest; Res: THorseResponse)
//    var
//      sNome: String;
//    begin
//      if not PERMITE_EXCLUSAO then
//        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');
//
//      sNome := ForceCombine(ConcatenaQuery(Req), Req.Query.Items['nome']);
//
//      if not TFile.Exists(sNome) then
//        raise EHorseException.New.Status(THTTPStatus.NotFound).Error('Arquivo "'+ Req.Query.Items['nome'] +'" não encontrado!');
//
//      if not DumpBin(sNome) then
//        raise EHorseException.New.Status(THTTPStatus.InternalServerError).Error('Erro ao remover o arquivo "'+ Req.Query.Items['nome'] +'"!');
//    end
//  );

  THorse.Get(
    '/icone',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sNome: String;
      sExtensao: String;
      sIcone: String;
    begin
      sNome := Req.Query.Items['nome'];
      sExtensao := Req.Query.Items['extensao'];

      if sExtensao.IsEmpty then
        sIcone := 'folder'
      else
      for var Icone in Icones do
      begin
        if (IndexText(sExtensao, Icone.fileExtensions) <> -1) or (IndexText(sNome, Icone.fileNames) <> -1) then
        begin
          sIcone := Icone.name;
          Break;
        end;
      end;

      if sIcone.IsEmpty then
        sIcone := 'document';

       Res.SendFile('icons\'+ sIcone +'.svg');
    end
  );

  THorse.Get(
    '/miniatura',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.SendFile(Miniatura(Req.Query.Items['id'].ToInteger));
    end
  );

  THorse.Get(
    '/atualizar',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Indexar;
      Processar;
    end
  );

  TPool.Start('banco.db');
  try
    TPool.Instance.Connection.ExecSQL(
      sl +'pragma foreign_keys = on; '+
      sl +
      sl +'create table if not exists pasta( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    pasta_id integer null,   '+
      sl +'    nome text not null, '+
      sl +'    foreign key (pasta_id) references pasta(id), '+
      sl +'    unique (pasta_id, nome) '+
      sl +'); '+
      sl +
      sl +'create table if not exists arquivo( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    pasta_id integer null, '+
      sl +'    nome text not null,     '+
      sl +'    extensao text null, '+
      sl +'    tamanho integer not null, '+
      sl +'    criado text null, '+
      sl +'    modificado text null, '+
      sl +'    foreign key (pasta_id) references pasta(id), '+
      sl +'    unique (pasta_id, nome, extensao) '+
      sl +'); '+
      sl +
      sl +'create table if not exists foto( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    arquivo_id integer, '+
      sl +'    tirada text null, '+
      sl +'    camera text null, '+
      sl +'    f real null, '+
      sl +'    exposicao real null, '+
      sl +'    distancia_focal real null, '+
      sl +'    iso integer null,  '+
      sl +'    megapixels integer null, '+
      sl +'    largura integer not null, '+
      sl +'    altura integer not null, '+
      sl +'    coordenadas text null, '+
      sl +'    altitude real null, '+
      sl +'    flash integer, '+
      sl +'    foreign key (arquivo_id) references arquivo(id), '+
      sl +'    unique (arquivo_id) '+
      sl +'); '+
      sl +
      sl +'create table if not exists miniatura( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    foto_id integer, '+
      sl +'    largura integer not null, '+
      sl +'    altura integer not null, '+
      sl +'    bytes blob,  '+
      sl +'    foreign key (foto_id) references foto(id), '+
      sl +'    unique (foto_id, largura, altura) '+
      sl +'); '+
      sl +
      sl +'create table if not exists album( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    nome text not null, '+
      sl +'    unique (nome) '+
      sl +'); '+
      sl +
      sl +'create table if not exists album_foto( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    album_id integer not null, '+
      sl +'    foto_id integer not null, '+
      sl +'    foreign key (album_id) references album(id), '+
      sl +'    foreign key (foto_id) references foto(id), '+
      sl +'    unique (album_id, foto_id) '+
      sl +'); '+
      sl +
      sl +'create table if not exists classificacao( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    descricao text not null, '+
      sl +'    unique (descricao) '+
      sl +'); '+
      sl +
      sl +'create table if not exists classificacao_foto( '+
      sl +'    id integer primary key autoincrement, '+
      sl +'    foto_id integer not null, '+
      sl +'    classificacao_id integer not null, '+
      sl +'    foreign key (foto_id) references foto(id), '+
      sl +'    foreign key (classificacao_id) references classificacao(id), '+
      sl +'    unique (foto_id, classificacao_id) '+
      sl +'); '
    );

    THorse.Listen(
      PORTA,
      procedure
      begin
        Writeln('Servidor iniciado na porta: '+ PORTA.ToString +' 🚀');
      end
    );
  finally
    TPool.Stop;
  end;
end.

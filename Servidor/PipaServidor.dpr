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
  System.JSON,
  System.JSON.Serializers,
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
    var
      sPasta: String;
    begin
      sPasta := ConcatenaQuery(Req);
      Res.Send<TJSONArray>(ItensParaJSON(RemoverRaiz(RAIZ, ListarNaoRecursivo(sPasta))));
    end
  );

  THorse.Put(
    '/pasta',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sPasta: String;
      sNome: String;
    begin
      if SOMENTE_LEITURA then
        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');

      sPasta := ConcatenaQuery(Req);
      sNome := Req.Body<TJSONValue>.GetValue<String>('nome');

      TDirectory.CreateDirectory(ForceCombine(sPasta, sNome));
    end
  );

  THorse.Delete(
    '/pasta',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sPasta: String;
    begin
      if SOMENTE_LEITURA then
        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');

      sPasta := ConcatenaQuery(Req);

      if not TDirectory.Exists(sPasta) then
        raise EHorseException.New.Status(THTTPStatus.NotFound).Error('Pasta "'+ Req.Query.Items['pasta'] +'" não encontrada!');

      if not DumpBin(sPasta + TPath.DirectorySeparatorChar) then
        raise EHorseException.New.Status(THTTPStatus.InternalServerError).Error('Erro ao remover a pasta "'+ Req.Query.Items['pasta'] +'"!');
    end
  );

  THorse.Put(
    '/arquivo',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sPasta: String;
      sNome: String;
    begin
      if SOMENTE_LEITURA then
        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');

      sPasta := ConcatenaQuery(Req);
      sNome := Req.Query.Items['nome'];

      TDirectory.CreateDirectory(sPasta);

      Req.Body<TStringStream>.SaveToFile(ForceCombine(sPasta, sNome));
    end
  );

  THorse.Get(
    '/arquivo',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sNome: String;
    begin
      sNome := ForceCombine(ConcatenaQuery(Req), Req.Query.Items['nome']);

      if not TFile.Exists(sNome) then
        raise EHorseException.New.Status(THTTPStatus.NotFound).Error('Arquivo "'+ Req.Query.Items['nome'] +'" não encontrado!');

      Res.SendFile(sNome);
    end
  );

  THorse.Delete(
    '/arquivo',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sNome: String;
    begin
      if SOMENTE_LEITURA then
        raise EHorseException.New.Status(THTTPStatus.ServiceUnavailable).Error('Modo somente leitura habilitado!');

      sNome := ForceCombine(ConcatenaQuery(Req), Req.Query.Items['nome']);

      if not TFile.Exists(sNome) then
        raise EHorseException.New.Status(THTTPStatus.NotFound).Error('Arquivo "'+ Req.Query.Items['nome'] +'" não encontrado!');

      if not DumpBin(sNome) then
        raise EHorseException.New.Status(THTTPStatus.InternalServerError).Error('Erro ao remover o arquivo "'+ Req.Query.Items['nome'] +'"!');
    end
  );

  THorse.Get(
    '/icone',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sNome: String;
      sExtensao: String;
      sIcone: String;
    begin
      sNome := ForceCombine(ConcatenaQuery(Req), Req.Query.Items['nome']);
      sExtensao := ExtractFileExt(sNome).Replace('.', EmptyStr).ToLower;

      if TDirectory.Exists(sNome) then
        sIcone := 'folder'
      else
      if TFile.Exists(sNome) then
      begin
        for var Icone in Icones do
        begin
          if (IndexText(sExtensao, Icone.fileExtensions) <> -1) or (IndexText(sNome, Icone.fileNames) <> -1) then
          begin
            sIcone := Icone.name;
            Break;
          end;
        end;
      end
      else
        raise EHorseException.New.Status(THTTPStatus.NotFound).Error('Pasta ou arquivo "'+ sExtensao +'" não encontrado!');

      if sIcone.IsEmpty then
        Res.Send('')
      else
        Res.SendFile('icons\'+ sIcone +'.svg');
    end
  );

  THorse.Get(
    '/miniatura',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      sNome: String;
      sExtensao: String;
      sSeparador: String;
      sPasta: String;
    begin
      sSeparador := Req.Query.Items['separador'];
      sPasta := Req.Query.Items['pasta'];
      sPasta := sPasta.Replace(sSeparador, TPath.DirectorySeparatorChar);
      sNome := Req.Query.Items['nome'];
      sExtensao := ExtractFileExt(sNome).Replace('.', EmptyStr);
      sNome := ChangeFileExt(sNome, EmptyStr);
      Res.SendFile(Miniatura(sPasta, sNome, sExtensao));
    end
  );

  THorse.Get(
    '/fotos/indexar',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Indexar;
    end
  );

  THorse.Get(
    '/fotos/processar',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Processar;
    end
  );

  TPool.Start('banco.db');
  try
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

// Eduardo - 21/11/2024
unit Pipa.Miniatura;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Pipa.Tipos;

var
  ListaPendenteDownload: TList<TItem>;

implementation

uses
  System.SysUtils,
  System.Threading,
  System.JSON,
  System.IOUtils,
  REST.API;

const
  BASEURL = 'http://100.91.113.91:500/';

var
  PararThread: Boolean;
  DownloadMiniatura: ITask;

procedure Executar;
var
  IAPI: TRESTAPI;
  Lista: TItens;
  sArquivo: String;
  sRaiz: String;
begin
  IAPI := TRESTAPI.Create;
  try
    IAPI.Host(BASEURL);
    IAPI.Route('miniatura');

    while not PararThread do
    try
      TMonitor.Enter(ListaPendenteDownload);
      try
        Lista := ListaPendenteDownload.ToArray;
      finally
        TMonitor.Exit(ListaPendenteDownload);
      end;

      for var Item in Lista do
      begin
        IAPI.Headers.Clear;
        IAPI.Query.Clear;
        IAPI.Body.Clear;
        IAPI.Params.Clear;

        IAPI.Query(
          TJSONObject.Create
            .AddPair('separador', TPath.DirectorySeparatorChar)
            .AddPair('pasta', Item.Pasta.ToString)
            .AddPair('nome', Item.Nome)
        );

        IAPI.GET;

        if IAPI.Response.Status <> TResponseStatus.Sucess then
        begin
          TMonitor.Enter(ListaPendenteDownload);
          try
            for var I := Pred(ListaPendenteDownload.Count) downto 0 do
              if (ListaPendenteDownload[I].Tipo = Item.Tipo) and (ListaPendenteDownload[I].Pasta.ToString = Item.Pasta.ToString) and (ListaPendenteDownload[I].Nome = Item.Nome) then
                ListaPendenteDownload.Delete(I);
          finally
            TMonitor.Exit(ListaPendenteDownload);
          end;

          Continue;
        end;

        sRaiz := TPath.Combine(TPath.GetCachePath, 'pipa');
        if not TDirectory.Exists(sRaiz) then
          TDirectory.CreateDirectory(sRaiz);
        sRaiz := TPath.Combine(sRaiz, Item.Pasta.ToString);
        if not TDirectory.Exists(sRaiz) then
          TDirectory.CreateDirectory(sRaiz);

        sArquivo := TPath.Combine(sRaiz, Item.Nome);

        IAPI.Response.ToStream.SaveToFile(sArquivo);

        TMonitor.Enter(ListaPendenteDownload);
        try
          for var I := Pred(ListaPendenteDownload.Count) downto 0 do
            if (ListaPendenteDownload[I].Tipo = Item.Tipo) and (ListaPendenteDownload[I].Pasta.ToString = Item.Pasta.ToString) and (ListaPendenteDownload[I].Nome = Item.Nome) then
              ListaPendenteDownload.Delete(I);
        finally
          TMonitor.Exit(ListaPendenteDownload);
        end;

        if PararThread then
          Break;
      end;

      if Length(Lista) = 0 then
        Sleep(250);
    except
    end;
  finally
    FreeAndNil(IAPI);
  end;
end;

initialization
  ListaPendenteDownload := TList<TItem>.Create;
  PararThread := False;
  DownloadMiniatura := TTask.Run(Executar);

finalization
  PararThread := True;
  DownloadMiniatura.Wait(1000);
  FreeAndNil(ListaPendenteDownload);

end.

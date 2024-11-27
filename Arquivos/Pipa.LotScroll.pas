// Eduardo - 15/11/2024
unit Pipa.LotScroll;

interface

uses
  System.Types,
  System.Classes,
  FMX.StdCtrls,
  FMX.Layouts;

type
  TFillPage = procedure(PageIndex: Integer; Page: TLayout) of object;

  TLotScroll = class(TLayout)
  private
    Box: TVertScrollBox;
    Scroll: TSmallScrollBar;
    Pages: TArray<TLayout>;
    FillPage: TFillPage;
    FInicio: Boolean;
    procedure ScrollChange(Sender: TObject);
    procedure BoxViewportPositionChange(Sender: TObject; const OldViewportPosition, NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
    procedure UpdatePages(ScrollValue, ViewportSize: Single);
  public
    constructor Create(AOwner: TComponent; TotalPages, PageHeight: Integer); reintroduce;
    property OnFillPage: TFillPage read FillPage write FillPage;
    function Visiveis: TArray<TLayout>;
  end;

implementation

uses
  FMX.Types,
  FMX.Controls;

{ TLotScroll }

constructor TLotScroll.Create(AOwner: TComponent; TotalPages, PageHeight: Integer);
var
  I: Integer;
  Page: TLayout;
  CurrentPos: Single;
begin
  inherited Create(AOwner);

  FInicio := True;

  Box := TVertScrollBox.Create(Self);
  Box.Align := TAlignLayout.Client;
  Box.ShowScrollBars := False;
  Box.OnViewportPositionChange := BoxViewportPositionChange;
  Box.Parent := Self;

  Scroll := TSmallScrollBar.Create(Self);
  Scroll.Orientation := TOrientation.Vertical;
  Scroll.Align := TAlignLayout.Right;
  Scroll.OnChange := ScrollChange;
  Scroll.Parent := Self;

  CurrentPos := 0;
  Pages := [];

  for I := 0 to Pred(TotalPages) do
  begin
    Page := TLayout.Create(Box);
    Page.Align := TAlignLayout.None;
    Page.Height := PageHeight;
    Pages := Pages + [Page];
    Page.Parent := Box;
    Page.Position.Y := CurrentPos;
    CurrentPos := CurrentPos + PageHeight;
  end;

  Scroll.Max := CurrentPos + PageHeight;
  Scroll.ViewportSize := Box.Height;
  Scroll.Value := 0;
  Box.ViewportPosition := TPointF.Create(0, 0);
end;

procedure TLotScroll.BoxViewportPositionChange(Sender: TObject; const OldViewportPosition, NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
begin
  Scroll.Max := Box.ContentBounds.Height;
  Scroll.ViewportSize := Box.Height;
  Scroll.Value := NewViewportPosition.Y;

  UpdatePages(Scroll.Value, Scroll.ViewportSize);
end;

procedure TLotScroll.ScrollChange(Sender: TObject);
begin
  Box.ViewportPosition := TPointF.Create(0, Scroll.Value);
end;

procedure TLotScroll.UpdatePages(ScrollValue, ViewportSize: Single);
var
  I, J: Integer;
  Item: TFmxObject;
begin
  for I := 0 to Pred(Length(Pages)) do
  begin
    if (ScrollValue < Pages[I].Position.Y + Pages[I].Size.Height) and (ScrollValue + ViewportSize > Pages[I].Position.Y) then
    begin
      if Pages[I].ComponentCount = 0 then
        FillPage(I, Pages[I]);
    end
    else
    begin
      for J := Pred(Pages[I].ComponentCount) downto 0 do
      begin
        Item := Pages[I].Components[J] as TFmxObject;
        Pages[I].RemoveObject(Item);
        Item.Free;
      end;
    end;
  end;
end;

function TLotScroll.Visiveis: TArray<TLayout>;
var
  I: Integer;
begin
  Result := [];
  for I := 0 to Pred(Length(Pages)) do
    if Pages[I].ComponentCount > 0 then
      Result := Result + [Pages[I]];
end;

end.

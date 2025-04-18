// Eduardo - 15/11/2024
unit Pipa.LotScroll;

interface

uses
  System.Types,
  System.Classes,
  System.Generics.Collections,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.Types;

type
  TFillPage = procedure(PageIndex: Integer; Page: TLayout) of object;

  TLotScroll = class(TLayout)
  private
    Box: TVertScrollBox;
    Scroll: TSmallScrollBar;
    FPages: TArray<TLayout>;
    FTotalPages: Integer;
    FPageHeight: Integer;
    FillPage: TFillPage;
    FInicio: Boolean;
    FCurrentPos: Single;
    FSetPos: Single;
    procedure ScrollChange(Sender: TObject);
    procedure BoxViewportPositionChange(Sender: TObject; const OldViewportPosition, NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
    procedure UpdatePages(ScrollValue, ViewportSize: Single);
    function GetScrollPosition: Single;
    procedure SetScrollPosition(const Value: Single);
  public
    constructor Create(AOwner: TComponent; TotalPages, PageHeight: Integer); reintroduce;
    property OnFillPage: TFillPage read FillPage write FillPage;
    property ScrollPosition: Single read GetScrollPosition write SetScrollPosition;
    function Visiveis: TArray<TLayout>;
    function Page(I: Integer): TLayout;
  end;

implementation

uses
  FMX.Controls;

{ TLotScroll }

function TLotScroll.Page(I: Integer): TLayout;
begin
  if I >= Length(FPages) then
  begin
    Result := TLayout.Create(Box);
    Result.Tag := I;
    Result.Align := TAlignLayout.None;
    Result.Height := FPageHeight;
    FPages := FPages + [Result];
    Result.Parent := Box;
    Result.Position.Y := FCurrentPos;
    FCurrentPos := FCurrentPos + FPageHeight;
  end
  else
    Result := FPages[I];
end;

constructor TLotScroll.Create(AOwner: TComponent; TotalPages, PageHeight: Integer);
begin
  inherited Create(AOwner);

  FInicio := True;
  FTotalPages := TotalPages;
  FPageHeight := PageHeight;
  FCurrentPos := 0;
  FPages := [];

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

  Scroll.Max := TotalPages * PageHeight;
  Scroll.ViewportSize := Box.Height;
  Scroll.Value := 0;
  Box.ViewportPosition := TPointF.Create(0, 0);
end;

function TLotScroll.GetScrollPosition: Single;
begin
  Result := Scroll.Value;
end;

procedure TLotScroll.SetScrollPosition(const Value: Single);
begin
  FSetPos := Value;
end;

procedure TLotScroll.BoxViewportPositionChange(Sender: TObject; const OldViewportPosition, NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
begin
  Scroll.Max := Box.ContentBounds.Height;
  Scroll.ViewportSize := Box.Height;
  Scroll.Value := NewViewportPosition.Y;

  UpdatePages(Scroll.Value, Scroll.ViewportSize);

  if FSetPos > 0 then
  begin
    Scroll.Value := FSetPos;
    if Scroll.Value > 0 then
      FSetPos := 0;
  end;
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
  for I := 0 to Pred(FTotalPages) do
  begin
    if (ScrollValue < Page(I).Position.Y + Page(I).Size.Height) and (ScrollValue + ViewportSize > Page(I).Position.Y) then
    begin
      if Page(I).ComponentCount = 0 then
        FillPage(I, Page(I));
    end
    else
    begin
      for J := Pred(Page(I).ComponentCount) downto 0 do
      begin
        Item := Page(I).Components[J] as TFmxObject;
        Page(I).RemoveObject(Item);
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
  for I := 0 to Pred(FTotalPages) do
    if Page(I).ComponentCount > 0 then
      Result := Result + [Page(I)];
end;

end.

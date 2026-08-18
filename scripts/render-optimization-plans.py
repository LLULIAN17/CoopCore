"""Renderiza comparaciones legibles a partir de los planes XML capturados."""

from __future__ import annotations

import argparse
import csv
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


WIDTH = 1600
HEIGHT = 900
NAVY = "#10243E"
BLUE = "#276FBF"
TEAL = "#1B998B"
RED = "#D1495B"
GOLD = "#F2B134"
INK = "#17202A"
MUTED = "#5D6D7E"
PAPER = "#F7F9FC"
WHITE = "#FFFFFF"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    filename = "arialbd.ttf" if bold else "arial.ttf"
    path = Path("C:/Windows/Fonts") / filename
    return ImageFont.truetype(str(path), size=size)


def number(value: str) -> float:
    return float(value.replace(",", "."))


def wrapped(draw: ImageDraw.ImageDraw, text: str, box: tuple[int, int, int, int], size: int) -> None:
    x1, y1, x2, _ = box
    average_chars = max(20, int((x2 - x1) / (size * 0.54)))
    lines = textwrap.wrap(text or "(ninguno)", width=average_chars)
    draw.multiline_text((x1, y1), "\n".join(lines), fill=INK, font=font(size), spacing=9)


def render_case(row: dict[str, str], output: Path) -> None:
    before = number(row["CostoAntes"])
    after = number(row["CostoDespues"])
    reduction = -number(row["DeltaPorcentaje"])
    maximum = max(before, after, 0.000001)

    image = Image.new("RGB", (WIDTH, HEIGHT), PAPER)
    draw = ImageDraw.Draw(image)

    draw.rectangle((0, 0, WIDTH, 150), fill=NAVY)
    draw.text((70, 38), "COOPCORE · EVIDENCIA DE OPTIMIZACION", fill=GOLD, font=font(24, True))
    draw.text((70, 78), row["Caso"].replace("_", " ").upper(), fill=WHITE, font=font(39, True))
    draw.text((70, 124), f"Indice evaluado: {row['Indice']}", fill="#DDE8F5", font=font(21))

    draw.rounded_rectangle((70, 185, 1530, 345), radius=18, fill=WHITE, outline="#D7E0EA", width=2)
    draw.text((105, 210), "Costo estimado del subarbol", fill=INK, font=font(25, True))

    labels = [("ANTES", before, RED, 255), ("DESPUES", after, TEAL, 300)]
    for label, value, color, y in labels:
        draw.text((105, y - 5), label, fill=MUTED, font=font(19, True))
        bar_x = 245
        bar_width = int(950 * (value / maximum))
        draw.rounded_rectangle((bar_x, y, bar_x + max(4, bar_width), y + 30), radius=8, fill=color)
        draw.text((1220, y - 3), f"{value:.8f}", fill=INK, font=font(22, True))

    badge_color = TEAL if reduction >= 0 else RED
    badge_text = f"REDUCCION {reduction:.2f}%" if reduction >= 0 else f"AUMENTO {-reduction:.2f}%"
    draw.rounded_rectangle((1250, 205, 1495, 248), radius=14, fill=badge_color)
    draw.text((1270, 217), badge_text, fill=WHITE, font=font(17, True))

    cards = [
        (70, 385, 765, 750, "PLAN ANTES", RED, row["OperadoresAntes"], row["IndicesAntes"]),
        (835, 385, 1530, 750, "PLAN DESPUES", TEAL, row["OperadoresDespues"], row["IndicesDespues"]),
    ]
    for x1, y1, x2, y2, title, color, operators, indexes in cards:
        draw.rounded_rectangle((x1, y1, x2, y2), radius=18, fill=WHITE, outline="#D7E0EA", width=2)
        draw.rectangle((x1, y1, x2, y1 + 60), fill=color)
        draw.text((x1 + 30, y1 + 16), title, fill=WHITE, font=font(24, True))
        draw.text((x1 + 30, y1 + 90), "Operadores fisicos", fill=MUTED, font=font(18, True))
        wrapped(draw, operators, (x1 + 30, y1 + 125, x2 - 30, y1 + 235), 22)
        draw.line((x1 + 30, y1 + 245, x2 - 30, y1 + 245), fill="#E4EAF0", width=2)
        draw.text((x1 + 30, y1 + 275), "Indices presentes en el plan", fill=MUTED, font=font(18, True))
        wrapped(draw, indexes, (x1 + 30, y1 + 310, x2 - 30, y2 - 20), 22)

    draw.text(
        (70, 790),
        "Fuente primaria: SQL Server SET SHOWPLAN_XML ON · Los archivos .sqlplan se abren directamente en SSMS.",
        fill=MUTED,
        font=font(19),
    )
    draw.text(
        (70, 825),
        f"Archivos: {row['Caso']}_antes.sqlplan · {row['Caso']}_despues.sqlplan",
        fill=BLUE,
        font=font(18, True),
    )

    image.save(output, format="PNG", optimize=True)


def render_summary(rows: list[dict[str, str]], output: Path) -> None:
    image = Image.new("RGB", (WIDTH, HEIGHT), PAPER)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, WIDTH, 150), fill=NAVY)
    draw.text((70, 38), "COOPCORE · OPTIMIZACION", fill=GOLD, font=font(24, True))
    draw.text((70, 78), "COMPARACION DE COSTOS ESTIMADOS", fill=WHITE, font=font(39, True))

    y = 195
    for row in rows:
        before = number(row["CostoAntes"])
        after = number(row["CostoDespues"])
        reduction = -number(row["DeltaPorcentaje"])
        maximum = max(before, after, 0.000001)

        draw.text((70, y), row["Caso"].replace("_", " ").title(), fill=INK, font=font(21, True))
        draw.text((470, y), f"{before:.8f}", fill=RED, font=font(18, True))
        draw.text((650, y), "→", fill=MUTED, font=font(21, True))
        draw.text((705, y), f"{after:.8f}", fill=TEAL, font=font(18, True))
        draw.text((900, y), f"-{reduction:.2f}%", fill=TEAL, font=font(20, True))
        draw.text((1080, y), row["Indice"], fill=BLUE, font=font(17))

        bar_y = y + 38
        draw.rounded_rectangle((470, bar_y, 470 + int(500 * before / maximum), bar_y + 18), radius=5, fill=RED)
        draw.rounded_rectangle((470, bar_y + 25, 470 + int(500 * after / maximum), bar_y + 43), radius=5, fill=TEAL)
        y += 125

    draw.rounded_rectangle((70, 810, 1530, 865), radius=14, fill="#E8F3F1")
    draw.text(
        (95, 827),
        "Rojo: antes · Verde: despues · Medicion reproducible sobre el mismo seed y la misma instancia.",
        fill=INK,
        font=font(19, True),
    )
    image.save(output, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="docs/evidencias/planes")
    args = parser.parse_args()
    directory = Path(args.input).resolve()

    with (directory / "resumen_costos_estimados.csv").open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))

    for row in rows:
        render_case(row, directory / f"{row['Caso']}_comparacion.png")
    render_summary(rows, directory / "resumen_costos_estimados.png")
    print(f"Se generaron {len(rows) + 1} imagenes en {directory}")


if __name__ == "__main__":
    main()

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT = REPO_ROOT / "output" / "pdf" / "Prompt_Finalizacion_CoopCore.pdf"

NAVY = colors.HexColor("#17233C")
BLUE = colors.HexColor("#285E8E")
PALE_BLUE = colors.HexColor("#EAF2F8")
PALE_GRAY = colors.HexColor("#F4F6F8")
MID_GRAY = colors.HexColor("#5E6A7D")
GREEN = colors.HexColor("#287A5C")


def register_fonts():
    windows_fonts = Path("C:/Windows/Fonts")
    regular = windows_fonts / "arial.ttf"
    bold = windows_fonts / "arialbd.ttf"
    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont("CoopCore", str(regular)))
        pdfmetrics.registerFont(TTFont("CoopCore-Bold", str(bold)))
        return "CoopCore", "CoopCore-Bold"
    return "Helvetica", "Helvetica-Bold"


FONT, FONT_BOLD = register_fonts()


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#D6DCE5"))
    canvas.line(doc.leftMargin, 0.55 * inch, LETTER[0] - doc.rightMargin, 0.55 * inch)
    canvas.setFont(FONT, 8)
    canvas.setFillColor(MID_GRAY)
    canvas.drawString(doc.leftMargin, 0.36 * inch, "CoopCore - Prompt de finalizacion y validacion")
    canvas.drawRightString(LETTER[0] - doc.rightMargin, 0.36 * inch, f"Pagina {doc.page}")
    canvas.restoreState()


def bullet(text, styles):
    return Paragraph(f"- {text}", styles["BulletCustom"])


def numbered(number, title, detail, styles):
    body = (
        f"<font color='#285E8E'><b>{number}.</b></font> "
        f"<b>{title}</b><br/><font color='#374151'>{detail}</font>"
    )
    return Paragraph(body, styles["Numbered"])


def build_pdf():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="CoverEyebrow",
            fontName=FONT_BOLD,
            fontSize=10,
            leading=13,
            textColor=BLUE,
            alignment=TA_CENTER,
            spaceAfter=14,
        )
    )
    styles.add(
        ParagraphStyle(
            name="CoverTitle",
            fontName=FONT_BOLD,
            fontSize=26,
            leading=31,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=16,
        )
    )
    styles.add(
        ParagraphStyle(
            name="CoverSubtitle",
            fontName=FONT,
            fontSize=12,
            leading=18,
            textColor=MID_GRAY,
            alignment=TA_CENTER,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H1Custom",
            fontName=FONT_BOLD,
            fontSize=18,
            leading=22,
            textColor=NAVY,
            spaceAfter=12,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H2Custom",
            fontName=FONT_BOLD,
            fontSize=12,
            leading=16,
            textColor=BLUE,
            spaceBefore=10,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodyCustom",
            fontName=FONT,
            fontSize=10,
            leading=15,
            textColor=colors.HexColor("#253047"),
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BulletCustom",
            parent=styles["BodyCustom"],
            leftIndent=14,
            firstLineIndent=-8,
            spaceAfter=5,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Numbered",
            parent=styles["BodyCustom"],
            leftIndent=8,
            spaceAfter=10,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Small",
            fontName=FONT,
            fontSize=8.5,
            leading=12,
            textColor=MID_GRAY,
            alignment=TA_LEFT,
        )
    )

    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=LETTER,
        rightMargin=0.72 * inch,
        leftMargin=0.72 * inch,
        topMargin=0.68 * inch,
        bottomMargin=0.78 * inch,
        title="Prompt para finalizar CoopCore",
        author="Equipo CoopCore",
        subject="Revision, validacion y fusion de la entrega final",
    )

    story = []
    story.append(Spacer(1, 1.15 * inch))
    story.append(Paragraph("COOPCORE - ENTREGA FINAL", styles["CoverEyebrow"]))
    story.append(Paragraph("Prompt de revision, validacion y publicacion", styles["CoverTitle"]))
    story.append(
        Paragraph(
            "Instrucciones listas para copiar y usar con un agente de desarrollo antes de fusionar la PR #3.",
            styles["CoverSubtitle"],
        )
    )
    story.append(Spacer(1, 0.55 * inch))
    summary = Table(
        [
            [Paragraph("Repositorio", styles["Small"]), Paragraph("github.com/LLULIAN17/CoopCore", styles["BodyCustom"])],
            [Paragraph("Solicitud", styles["Small"]), Paragraph("PR #3 - Completar requisitos de entrega final", styles["BodyCustom"])],
            [Paragraph("Rama base", styles["Small"]), Paragraph("main", styles["BodyCustom"])],
            [Paragraph("Resultado esperado", styles["Small"]), Paragraph("Pruebas aprobadas, cambios revisados y fusion segura", styles["BodyCustom"])],
        ],
        colWidths=[1.35 * inch, 4.75 * inch],
        hAlign="CENTER",
    )
    summary.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), PALE_GRAY),
                ("BOX", (0, 0), (-1, -1), 0.7, colors.HexColor("#D6DCE5")),
                ("INNERGRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#D6DCE5")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 9),
                ("RIGHTPADDING", (0, 0), (-1, -1), 9),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    story.append(summary)
    story.append(Spacer(1, 0.35 * inch))
    story.append(
        Paragraph(
            "Documento preparado el 18 de agosto de 2026. La aprobacion del docente no debe darse por supuesta.",
            styles["Small"],
        )
    )
    story.append(PageBreak())

    story.append(Paragraph("Prompt listo para usar", styles["H1Custom"]))
    intro = Table(
        [[Paragraph("Copia desde el objetivo hasta la instruccion final. El agente debe trabajar sobre el repositorio real y conservar la trazabilidad en GitHub.", styles["BodyCustom"])]],
        colWidths=[6.1 * inch],
    )
    intro.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), PALE_BLUE),
                ("BOX", (0, 0), (-1, -1), 0.8, BLUE),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                ("TOPPADDING", (0, 0), (-1, -1), 10),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(intro)
    story.append(Spacer(1, 12))

    story.append(Paragraph("Contexto", styles["H2Custom"]))
    story.append(
        Paragraph(
            "Revisa el repositorio <b>https://github.com/LLULIAN17/CoopCore.git</b>. "
            "Trabaja con mucho cuidado y no borres, sobrescribas ni descartes cambios existentes sin verificar primero su origen.",
            styles["BodyCustom"],
        )
    )
    story.append(Paragraph("Objetivo", styles["H2Custom"]))
    story.append(
        Paragraph(
            "Finalizar la entrega de CoopCore incorporando correctamente la PR #3 a la rama <b>main</b>, "
            "solo despues de comprobar que el proyecto es reproducible, seguro para el entorno academico y coherente con los requisitos de entrega.",
            styles["BodyCustom"],
        )
    )
    story.append(Paragraph("Tareas", styles["H2Custom"]))
    story.append(Spacer(1, 8))
    story.append(numbered(1, "Revisar la PR #3", "Inspecciona todos los commits, archivos y diferencias de https://github.com/LLULIAN17/CoopCore/pull/3. Confirma que la rama de origen y la rama main esten actualizadas.", styles))
    story.append(
        numbered(
            2,
            "Verificar los entregables",
            "Comprueba la presencia y calidad del manual tecnico PDF de al menos 20 paginas, diagrama entidad-relacion, diccionario de datos, comparacion numerica de costos, planes de ejecucion SQL, evidencias de instalacion limpia, pruebas de API con JWT y scripts reproducibles.",
            styles,
        )
    )
    story.append(
        numbered(
            3,
            "Ejecutar las pruebas principales",
            "Compila la API .NET en Release; ejecuta lint, build y pruebas del frontend; instala todos los scripts SQL en una base temporal; y completa el smoke test de API, autenticacion, roles y conexion con SQL Server.",
            styles,
        )
    )
    story.append(PageBreak())
    story.append(Paragraph("Tareas - continuacion", styles["H1Custom"]))
    story.append(
        numbered(
            4,
            "Proteger informacion sensible",
            "Confirma que no se publiquen contrasenas reales, tokens JWT, cadenas de conexion privadas, archivos temporales ni binarios innecesarios. Los valores de laboratorio deben estar identificados como tales.",
            styles,
        )
    )
    story.append(
        numbered(
            5,
            "Corregir hallazgos",
            "Si encuentras errores, aplica cambios pequenos y verificables. Usa commits descriptivos, no mezcles temas distintos y vuelve a ejecutar las pruebas afectadas.",
            styles,
        )
    )
    story.append(
        numbered(
            6,
            "Preparar la fusion",
            "Si todas las pruebas aprueban, cambia la PR #3 de borrador a lista para revision. No fusiones cuando haya fallos, conflictos, archivos inesperados o dudas sobre el alcance.",
            styles,
        )
    )
    story.append(
        numbered(
            7,
            "Fusionar y comprobar main",
            "Despues de la aprobacion correspondiente, fusiona la PR, actualiza la copia local de main y confirma que el manual, los planes y las evidencias sean visibles en GitHub. El arbol de trabajo debe quedar limpio.",
            styles,
        )
    )
    story.append(
        numbered(
            8,
            "Entregar el informe final",
            "Resume pruebas ejecutadas, resultados, correcciones, commits, enlace al merge y cualquier riesgo pendiente. Distingue claramente entre validaciones tecnicas y aprobaciones externas.",
            styles,
        )
    )

    story.append(Paragraph("Reglas obligatorias", styles["H2Custom"]))
    rules = [
        "No declares el trabajo terminado si alguna prueba falla.",
        "No inventes aprobaciones, resultados ni evidencia de ejecucion.",
        "No afirmes que el diagrama ER fue aprobado si no existe confirmacion del docente.",
        "La ampliacion funcional del 50% debe quedar como validacion externa mientras el profesor no confirme el criterio.",
        "No expongas secretos en terminales, evidencias, commits o descripciones de la PR.",
        "No modifiques main directamente si el flujo del equipo exige revision mediante pull request.",
    ]
    for rule in rules:
        story.append(bullet(rule, styles))

    story.append(Spacer(1, 10))
    finish = Table(
        [[Paragraph("Resultado esperado", styles["H2Custom"]), Paragraph("Una entrega fusionada, reproducible y documentada, con todas las pruebas tecnicas aprobadas y los pendientes humanos identificados sin ambiguedad.", styles["BodyCustom"])]],
        colWidths=[1.55 * inch, 4.55 * inch],
    )
    finish.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#EAF6F0")),
                ("BOX", (0, 0), (-1, -1), 0.8, GREEN),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 9),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(finish)

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(OUTPUT)


if __name__ == "__main__":
    build_pdf()

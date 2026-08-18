"""Genera el manual tecnico final de CoopCore en formato PDF."""

from __future__ import annotations

import argparse
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.platypus import (
    BaseDocTemplate,
    Flowable,
    Frame,
    Image,
    KeepTogether,
    LongTable,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.platypus.tableofcontents import TableOfContents


NAVY = colors.HexColor("#10243E")
BLUE = colors.HexColor("#276FBF")
TEAL = colors.HexColor("#1B998B")
GOLD = colors.HexColor("#F2B134")
INK = colors.HexColor("#17202A")
MUTED = colors.HexColor("#5D6D7E")
PALE = colors.HexColor("#F4F7FA")
LINE = colors.HexColor("#D7E0EA")
WHITE = colors.white


def register_fonts() -> tuple[str, str, str]:
    fonts = Path("C:/Windows/Fonts")
    regular = fonts / "arial.ttf"
    bold = fonts / "arialbd.ttf"
    mono = fonts / "consola.ttf"
    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont("CoopSans", str(regular)))
        pdfmetrics.registerFont(TTFont("CoopSans-Bold", str(bold)))
        if mono.exists():
            pdfmetrics.registerFont(TTFont("CoopMono", str(mono)))
        return "CoopSans", "CoopSans-Bold", "CoopMono" if mono.exists() else "Courier"
    return "Helvetica", "Helvetica-Bold", "Courier"


FONT, FONT_BOLD, FONT_MONO = register_fonts()


class CoopDocTemplate(BaseDocTemplate):
    def __init__(self, filename: str, **kwargs):
        super().__init__(filename, **kwargs)
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            leftPadding=0,
            rightPadding=0,
            topPadding=0,
            bottomPadding=0,
            id="content",
        )
        self.addPageTemplates(PageTemplate(id="main", frames=[frame], onPage=self._decorate_page))
        self._bookmark_id = 0

    def beforeDocument(self):
        self._bookmark_id = 0

    def _decorate_page(self, canvas, doc):
        canvas.saveState()
        if doc.page > 1:
            canvas.setFillColor(NAVY)
            canvas.rect(0, letter[1] - 0.48 * inch, letter[0], 0.48 * inch, fill=1, stroke=0)
            canvas.setFont(FONT_BOLD, 8.5)
            canvas.setFillColor(GOLD)
            canvas.drawString(0.65 * inch, letter[1] - 0.31 * inch, "COOPCORE · MANUAL TECNICO")
        canvas.setStrokeColor(LINE)
        canvas.line(0.65 * inch, 0.50 * inch, letter[0] - 0.65 * inch, 0.50 * inch)
        canvas.setFont(FONT, 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(0.65 * inch, 0.31 * inch, "BTI23 Bases de Datos II · Entrega final · 17 agosto 2026")
        canvas.drawRightString(letter[0] - 0.65 * inch, 0.31 * inch, f"Pagina {doc.page}")
        canvas.restoreState()

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph) and flowable.style.name in {"Heading1", "Heading2"}:
            level = 0 if flowable.style.name == "Heading1" else 1
            text = flowable.getPlainText()
            self._bookmark_id += 1
            key = f"heading-{self._bookmark_id}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=level, closed=False)
            self.notify("TOCEntry", (level, text, self.page, key))


class ArchitectureDiagram(Flowable):
    def __init__(self, width: float, height: float = 3.2 * inch):
        super().__init__()
        self.width = width
        self.height = height

    def draw(self):
        canvas = self.canv
        box_w = self.width * 0.26
        gap = self.width * 0.10
        y = self.height * 0.34
        boxes = [
            (0, "FRONTEND", "Next.js\nCentro operativo"),
            (box_w + gap, "API .NET 10", "JWT + roles\nCapa de transporte"),
            (2 * (box_w + gap), "SQL SERVER", "Esquema coop\nLogica de negocio"),
        ]
        for index, (x, title, body) in enumerate(boxes):
            canvas.setFillColor(WHITE)
            canvas.setStrokeColor(BLUE if index < 2 else TEAL)
            canvas.setLineWidth(2)
            canvas.roundRect(x, y, box_w, 1.25 * inch, 10, fill=1, stroke=1)
            canvas.setFillColor(NAVY)
            canvas.setFont(FONT_BOLD, 11)
            canvas.drawCentredString(x + box_w / 2, y + 0.88 * inch, title)
            canvas.setFillColor(MUTED)
            canvas.setFont(FONT, 9)
            for line_no, line in enumerate(body.splitlines()):
                canvas.drawCentredString(x + box_w / 2, y + (0.60 - line_no * 0.20) * inch, line)
            if index < len(boxes) - 1:
                x1 = x + box_w + 8
                x2 = x + box_w + gap - 8
                arrow_y = y + 0.63 * inch
                canvas.setStrokeColor(GOLD)
                canvas.setFillColor(GOLD)
                canvas.setLineWidth(3)
                canvas.line(x1, arrow_y, x2, arrow_y)
                canvas.line(x2, arrow_y, x2 - 8, arrow_y + 5)
                canvas.line(x2, arrow_y, x2 - 8, arrow_y - 5)
        canvas.setFillColor(PALE)
        canvas.roundRect(0, 0.25 * inch, self.width, 0.55 * inch, 8, fill=1, stroke=0)
        canvas.setFillColor(INK)
        canvas.setFont(FONT_BOLD, 9)
        canvas.drawCentredString(
            self.width / 2,
            0.49 * inch,
            "HTTP/JSON -> validacion minima -> stored procedure -> transaccion y auditoria",
        )


class ERDiagram(Flowable):
    def __init__(self, width: float, height: float = 7.7 * inch):
        super().__init__()
        self.width = width
        self.height = height

    def draw(self):
        canvas = self.canv
        w = self.width
        h = self.height
        box_w = w * 0.26
        box_h = 0.75 * inch
        positions = {
            "Rol": (0.02 * w, 0.80 * h),
            "Empleado": (0.37 * w, 0.80 * h),
            "Auditoria": (0.72 * w, 0.80 * h),
            "Socio": (0.02 * w, 0.52 * h),
            "ProductoFinanciero": (0.37 * w, 0.52 * h),
            "GestionCobranza": (0.72 * w, 0.52 * h),
            "Cuenta": (0.02 * w, 0.22 * h),
            "Prestamo": (0.37 * w, 0.22 * h),
            "Movimiento": (0.02 * w, 0.02 * h),
            "Cuota": (0.72 * w, 0.22 * h),
        }
        keys = {
            "Rol": "PK RolID",
            "Empleado": "PK EmpleadoID · FK RolID",
            "Auditoria": "PK AuditoriaID · FK EmpleadoID",
            "Socio": "PK SocioID · UQ Cedula",
            "ProductoFinanciero": "PK ProductoFinancieroID",
            "GestionCobranza": "PK GestionCobranzaID · FK Prestamo/Empleado",
            "Cuenta": "PK CuentaID · FK Socio/Producto",
            "Prestamo": "PK PrestamoID · FK Socio/Producto",
            "Movimiento": "PK MovimientoID · FK Cuenta/Empleado",
            "Cuota": "PK CuotaID · FK PrestamoID",
        }
        relations = [
            ("Rol", "Empleado", "1:N"),
            ("Empleado", "Auditoria", "1:N"),
            ("Empleado", "GestionCobranza", "1:N"),
            ("Socio", "Cuenta", "1:N"),
            ("Socio", "Prestamo", "1:N"),
            ("ProductoFinanciero", "Cuenta", "1:N"),
            ("ProductoFinanciero", "Prestamo", "1:N"),
            ("Cuenta", "Movimiento", "1:N"),
            ("Empleado", "Movimiento", "1:N"),
            ("Prestamo", "Cuota", "1:N"),
            ("Prestamo", "GestionCobranza", "1:N"),
        ]

        canvas.setStrokeColor(colors.HexColor("#AAB7C4"))
        canvas.setFillColor(MUTED)
        canvas.setFont(FONT_BOLD, 7)
        for source, target, label in relations:
            sx, sy = positions[source]
            tx, ty = positions[target]
            x1, y1 = sx + box_w / 2, sy + box_h / 2
            x2, y2 = tx + box_w / 2, ty + box_h / 2
            canvas.line(x1, y1, x2, y2)
            canvas.drawString((x1 + x2) / 2 + 2, (y1 + y2) / 2 + 2, label)

        for table_name, (x, y) in positions.items():
            canvas.setFillColor(WHITE)
            canvas.setStrokeColor(TEAL if table_name in {"Prestamo", "Cuota", "GestionCobranza"} else BLUE)
            canvas.setLineWidth(1.5)
            canvas.roundRect(x, y, box_w, box_h, 7, fill=1, stroke=1)
            canvas.setFillColor(NAVY)
            canvas.setFont(FONT_BOLD, 8.5 if len(table_name) < 18 else 7.5)
            canvas.drawCentredString(x + box_w / 2, y + 0.47 * inch, table_name)
            canvas.setFillColor(MUTED)
            canvas.setFont(FONT, 6.5)
            canvas.drawCentredString(x + box_w / 2, y + 0.20 * inch, keys[table_name])

        canvas.setFillColor(PALE)
        canvas.roundRect(0, 0.90 * h, w, 0.55 * inch, 8, fill=1, stroke=0)
        canvas.setFillColor(INK)
        canvas.setFont(FONT_BOLD, 8.5)
        canvas.drawCentredString(w / 2, 0.90 * h + 0.22 * inch, "Modelo relacional final · 10 tablas · esquema coop")


def styles():
    sample = getSampleStyleSheet()
    result = {
        "Body": ParagraphStyle(
            "Body",
            parent=sample["BodyText"],
            fontName=FONT,
            fontSize=9.4,
            leading=13.2,
            textColor=INK,
            alignment=TA_JUSTIFY,
            spaceAfter=7,
        ),
        "Small": ParagraphStyle(
            "Small",
            parent=sample["BodyText"],
            fontName=FONT,
            fontSize=7.6,
            leading=10.2,
            textColor=INK,
        ),
        "Caption": ParagraphStyle(
            "Caption",
            parent=sample["BodyText"],
            fontName=FONT,
            fontSize=7.7,
            leading=10,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceBefore=4,
            spaceAfter=8,
        ),
        "Heading1": ParagraphStyle(
            "Heading1",
            parent=sample["Heading1"],
            fontName=FONT_BOLD,
            fontSize=19,
            leading=23,
            textColor=NAVY,
            spaceAfter=13,
        ),
        "Heading2": ParagraphStyle(
            "Heading2",
            parent=sample["Heading2"],
            fontName=FONT_BOLD,
            fontSize=13,
            leading=16,
            textColor=BLUE,
            spaceBefore=8,
            spaceAfter=8,
        ),
        "Heading3": ParagraphStyle(
            "Heading3",
            parent=sample["Heading3"],
            fontName=FONT_BOLD,
            fontSize=10.5,
            leading=13,
            textColor=TEAL,
            spaceBefore=7,
            spaceAfter=5,
        ),
        "Code": ParagraphStyle(
            "Code",
            parent=sample["Code"],
            fontName=FONT_MONO,
            fontSize=7.2,
            leading=9.4,
            textColor=INK,
            backColor=colors.HexColor("#EEF2F6"),
            borderColor=LINE,
            borderWidth=0.5,
            borderPadding=7,
            spaceBefore=5,
            spaceAfter=8,
        ),
        "Callout": ParagraphStyle(
            "Callout",
            parent=sample["BodyText"],
            fontName=FONT_BOLD,
            fontSize=9,
            leading=13,
            textColor=NAVY,
            backColor=colors.HexColor("#E8F3F1"),
            borderColor=TEAL,
            borderWidth=1,
            borderPadding=8,
            spaceBefore=6,
            spaceAfter=9,
        ),
    }
    return result


STYLES = styles()


def p(text: str, style: str = "Body") -> Paragraph:
    return Paragraph(text, STYLES[style])


def code(text: str) -> Paragraph:
    return Paragraph(escape(text).replace("\n", "<br/>"), STYLES["Code"])


def bullet(items: list[str]) -> list[Paragraph]:
    return [Paragraph(f"- {item}", STYLES["Body"]) for item in items]


def table(data, widths, header=True, small=False, repeat=1):
    converted = []
    for row_index, row in enumerate(data):
        converted.append(
            [
                cell if isinstance(cell, Flowable) else Paragraph(escape(str(cell)), STYLES["Small" if small else "Body"])
                for cell in row
            ]
        )
    result = LongTable(converted, colWidths=widths, repeatRows=repeat if header else 0, hAlign="LEFT")
    commands = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.45, LINE),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    if header:
        commands.extend(
            [
                ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
                ("FONTNAME", (0, 0), (-1, 0), FONT_BOLD),
            ]
        )
    for row_index in range(1 if header else 0, len(data)):
        if row_index % 2 == 0:
            commands.append(("BACKGROUND", (0, row_index), (-1, row_index), PALE))
    result.setStyle(TableStyle(commands))
    return result


DATA_DICTIONARY = {
    "coop.Socio": [
        ("SocioID", "INT IDENTITY", "PK, NN", "Identificador interno del socio."),
        ("Cedula", "NVARCHAR(20)", "UQ, NN", "Identificador legal unico."),
        ("Nombre", "NVARCHAR(80)", "NN", "Nombre del socio."),
        ("Apellido", "NVARCHAR(80)", "NN", "Apellido del socio."),
        ("Correo", "NVARCHAR(120)", "NULL", "Correo de contacto."),
        ("Telefono", "NVARCHAR(30)", "NULL", "Telefono de contacto."),
        ("Direccion", "NVARCHAR(250)", "NULL", "Direccion declarada."),
        ("Estado", "NVARCHAR(20)", "CK, DF", "ACTIVO, INACTIVO o SUSPENDIDO."),
        ("FechaRegistro", "DATETIME2", "DF, NN", "Fecha de alta del socio."),
    ],
    "coop.Rol": [
        ("RolID", "INT IDENTITY", "PK, NN", "Identificador del rol de aplicacion."),
        ("NombreRol", "NVARCHAR(50)", "UQ, NN", "Nombre unico del rol funcional."),
        ("Descripcion", "NVARCHAR(200)", "NULL", "Alcance del rol."),
        ("Estado", "NVARCHAR(20)", "CK, DF", "ACTIVO o INACTIVO."),
        ("FechaCreacion", "DATETIME2", "DF, NN", "Fecha de creacion."),
    ],
    "coop.Empleado": [
        ("EmpleadoID", "INT IDENTITY", "PK, NN", "Identificador interno."),
        ("Cedula", "NVARCHAR(20)", "UQ, NN", "Cedula unica del empleado."),
        ("Nombre", "NVARCHAR(80)", "NN", "Nombre."),
        ("Apellido", "NVARCHAR(80)", "NN", "Apellido."),
        ("Correo", "NVARCHAR(120)", "NULL", "Correo institucional."),
        ("Telefono", "NVARCHAR(30)", "NULL", "Telefono."),
        ("RolID", "INT", "FK, NULL", "Rol funcional asignado."),
        ("Estado", "NVARCHAR(20)", "CK, DF", "ACTIVO o INACTIVO."),
        ("FechaIngreso", "DATETIME2", "DF, NN", "Fecha de ingreso."),
        ("NombreUsuario", "NVARCHAR(50)", "UQ filtrado", "Usuario de la aplicacion."),
        ("PasswordHash", "VARBINARY(64)", "NULL", "Hash SHA2_256 de la clave con salt."),
        ("PasswordSalt", "VARBINARY(32)", "NULL", "Salt aleatorio de la clave."),
        ("UltimoLogin", "DATETIME2", "NULL", "Ultimo acceso correcto."),
        ("IntentosFallidos", "INT", "DF, NN", "Contador de accesos fallidos."),
        ("BloqueadoHasta", "DATETIME2", "NULL", "Fin del bloqueo temporal."),
    ],
    "coop.ProductoFinanciero": [
        ("ProductoFinancieroID", "INT IDENTITY", "PK, NN", "Identificador del producto."),
        ("CodigoProducto", "NVARCHAR(20)", "UQ, NN", "Codigo comercial unico."),
        ("NombreProducto", "NVARCHAR(100)", "UQ, NN", "Nombre comercial unico."),
        ("TipoProducto", "NVARCHAR(30)", "CK, NN", "AHORRO, PRESTAMO, CERTIFICADO u OTRO."),
        ("TasaInteres", "DECIMAL(18,2)", "CK, DF", "Tasa porcentual entre 0 y 100."),
        ("MontoMinimoApertura", "DECIMAL(18,2)", "CK, DF", "Monto minimo no negativo."),
        ("Estado", "NVARCHAR(20)", "CK, DF", "ACTIVO o INACTIVO."),
        ("FechaCreacion", "DATETIME2", "DF, NN", "Fecha de alta."),
    ],
    "coop.Cuenta": [
        ("CuentaID", "INT IDENTITY", "PK, NN", "Identificador interno."),
        ("NumeroCuenta", "NVARCHAR(30)", "UQ, NN", "Numero publico unico."),
        ("SocioID", "INT", "FK, NN", "Socio propietario."),
        ("ProductoFinancieroID", "INT", "FK, NN", "Producto asociado."),
        ("CreadaPorEmpleadoID", "INT", "FK, NULL", "Empleado que abrio la cuenta."),
        ("Saldo", "DECIMAL(18,2)", "CK, DF", "Saldo disponible no negativo."),
        ("EstadoCuenta", "NVARCHAR(20)", "CK, DF", "ACTIVA, INACTIVA, BLOQUEADA o CERRADA."),
        ("FechaApertura", "DATETIME2", "DF, NN", "Fecha de apertura."),
    ],
    "coop.Prestamo": [
        ("PrestamoID", "INT IDENTITY", "PK, NN", "Identificador interno."),
        ("NumeroPrestamo", "NVARCHAR(30)", "UQ, NN", "Numero publico unico."),
        ("SocioID", "INT", "FK, NN", "Socio deudor."),
        ("ProductoFinancieroID", "INT", "FK, NN", "Producto de credito."),
        ("AprobadoPorEmpleadoID", "INT", "FK, NULL", "Empleado aprobador."),
        ("MontoOriginal", "DECIMAL(18,2)", "CK, NN", "Principal otorgado."),
        ("SaldoPendiente", "DECIMAL(18,2)", "CK, NN", "Saldo entre cero y monto original."),
        ("TasaInteres", "DECIMAL(18,2)", "CK, NN", "Tasa contractual."),
        ("PlazoMeses", "INT", "CK, NN", "Plazo positivo en meses."),
        ("FechaDesembolso", "DATETIME2", "DF, NN", "Fecha de desembolso o aprobacion."),
        ("EstadoPrestamo", "NVARCHAR(20)", "CK, DF", "SOLICITADO, ACTIVO, PAGADO, MORA o CANCELADO."),
    ],
    "coop.Cuota": [
        ("CuotaID", "INT IDENTITY", "PK, NN", "Identificador de cuota."),
        ("PrestamoID", "INT", "FK, NN", "Prestamo propietario."),
        ("NumeroCuota", "INT", "UQ compuesta, CK", "Secuencia positiva dentro del prestamo."),
        ("FechaVencimiento", "DATE", "NN", "Fecha limite de pago."),
        ("MontoCuota", "DECIMAL(18,2)", "CK, NN", "Monto contractual positivo."),
        ("MontoPagado", "DECIMAL(18,2)", "CK, DF", "Acumulado entre cero y monto de cuota."),
        ("FechaPago", "DATETIME2", "NULL", "Fecha de pago completo."),
        ("EstadoCuota", "NVARCHAR(20)", "CK, DF", "PENDIENTE, PAGADA, VENCIDA o PARCIAL."),
    ],
    "coop.Movimiento": [
        ("MovimientoID", "BIGINT IDENTITY", "PK, NN", "Identificador contable."),
        ("CuentaID", "INT", "FK, NN", "Cuenta afectada."),
        ("TipoMovimiento", "NVARCHAR(30)", "CK, NN", "Deposito, retiro, transferencia o ajuste."),
        ("Monto", "DECIMAL(18,2)", "CK, NN", "Monto positivo."),
        ("Referencia", "NVARCHAR(50)", "NULL", "Referencia compartida de operacion."),
        ("Observacion", "NVARCHAR(300)", "NULL", "Detalle operativo."),
        ("FechaMovimiento", "DATETIME2", "DF, NN", "Marca temporal."),
        ("EjecutadoPorEmpleadoID", "INT", "FK, NN", "Empleado responsable."),
    ],
    "coop.Auditoria": [
        ("AuditoriaID", "BIGINT IDENTITY", "PK, NN", "Identificador del evento."),
        ("Entidad", "NVARCHAR(100)", "NN", "Objeto de negocio afectado."),
        ("EntidadID", "NVARCHAR(100)", "NULL", "Identificador textual del objeto."),
        ("Accion", "NVARCHAR(30)", "CK, NN", "INSERT, UPDATE, DELETE, EXECUTE, LOGIN u OTRO."),
        ("Descripcion", "NVARCHAR(4000)", "NULL", "Resumen del evento."),
        ("FechaEvento", "DATETIME2", "DF, NN", "Marca temporal."),
        ("UsuarioSQL", "NVARCHAR(128)", "DF, NN", "Login original de SQL Server."),
        ("UsuarioBD", "NVARCHAR(128)", "DF, NN", "Usuario de base de datos."),
        ("EmpleadoID", "INT", "FK, NULL", "Empleado de aplicacion asociado."),
    ],
    "coop.GestionCobranza": [
        ("GestionCobranzaID", "BIGINT IDENTITY", "PK, NN", "Identificador de gestion."),
        ("PrestamoID", "INT", "FK, NN", "Prestamo gestionado."),
        ("EmpleadoID", "INT", "FK, NN", "Empleado responsable."),
        ("FechaGestion", "DATETIME2", "DF, NN", "Marca temporal."),
        ("TipoGestion", "NVARCHAR(20)", "CK, NN", "Llamada, correo, SMS, visita, acuerdo u otro."),
        ("Resultado", "NVARCHAR(30)", "CK, NN", "Resultado normalizado del contacto."),
        ("Comentario", "NVARCHAR(500)", "NN", "Detalle obligatorio."),
        ("FechaCompromiso", "DATE", "NULL", "Fecha prometida de pago."),
        ("MontoCompromiso", "DECIMAL(18,2)", "CK, NULL", "Monto positivo prometido."),
    ],
}


PROCEDURES = [
    ("sp_ValidarLogin", "Autentica, audita intentos y aplica bloqueo temporal."),
    ("sp_ObtenerUsuarioPorCredenciales", "Valida credenciales para uso interno."),
    ("sp_CambiarPassword", "Renueva salt y hash de la clave."),
    ("sp_ConsultarSocio", "Consulta socio y resumen financiero."),
    ("sp_ConsultarSaldo", "Consulta saldo y ultimo movimiento."),
    ("sp_ConsultarMovimientos", "Lista movimientos por rango."),
    ("sp_RegistrarSocio", "Crea un socio y audita."),
    ("sp_CrearCuenta", "Abre cuenta y deposito inicial opcional."),
    ("sp_ConsultarPrestamo", "Devuelve resumen y cuotas."),
    ("sp_ConsultarAuditoria", "Filtra eventos de auditoria."),
    ("sp_RegistrarDeposito", "Deposito transaccional con OUTPUT."),
    ("sp_RegistrarRetiro", "Retiro con bloqueo y saldo suficiente."),
    ("sp_RegistrarTransferencia", "Transferencia atomica con dos OUTPUT."),
    ("sp_PagarCuota", "Pago de cuota, cuenta y prestamo atomicos."),
    ("sp_SolicitarPrestamo", "Crea solicitud con identificadores OUTPUT."),
    ("sp_AprobarPrestamo", "Activa una solicitud."),
    ("sp_RechazarPrestamo", "Cancela solicitud con motivo."),
    ("sp_GenerarAmortizacion", "Genera cuotas y ajusta redondeo."),
    ("sp_BuscarClientesMorosos", "Busca y pagina cartera vencida."),
    ("sp_ConsultarDashboardCartera", "Calcula indicadores y riesgo."),
    ("sp_BuscarProductosFinancieros", "Consulta catalogo y uso."),
    ("sp_GuardarProductoFinanciero", "Crea o actualiza productos."),
    ("sp_ConsultarAlertasCobranza", "Prioriza cuotas para cobro."),
    ("sp_RegistrarGestionCobranza", "Registra seguimiento y auditoria."),
]


ENDPOINTS = [
    ("POST", "/api/auth/login", "Publico", "sp_ValidarLogin"),
    ("POST", "/api/auth/cambiar-password", "Autenticado", "sp_CambiarPassword"),
    ("GET", "/api/socios/{id}", "Admin/Cajero", "sp_ConsultarSocio"),
    ("POST", "/api/socios", "Admin/Cajero", "sp_RegistrarSocio"),
    ("POST", "/api/cuentas", "Admin/Cajero", "sp_CrearCuenta"),
    ("GET", "/api/cuentas/{numero}/saldo", "Admin/Cajero", "sp_ConsultarSaldo"),
    ("GET", "/api/cuentas/{numero}/movimientos", "Admin/Cajero", "sp_ConsultarMovimientos"),
    ("POST", "/api/cuentas/depositos", "Admin/Cajero", "sp_RegistrarDeposito"),
    ("POST", "/api/cuentas/retiros", "Admin/Cajero", "sp_RegistrarRetiro"),
    ("POST", "/api/cuentas/transferencias", "Admin/Cajero", "sp_RegistrarTransferencia"),
    ("GET", "/api/prestamos/{numero}", "Admin/Oficial", "sp_ConsultarPrestamo"),
    ("POST", "/api/prestamos", "Admin/Oficial", "sp_SolicitarPrestamo"),
    ("POST", "/api/prestamos/{numero}/aprobar", "Admin/Oficial", "sp_AprobarPrestamo"),
    ("POST", "/api/prestamos/{numero}/rechazar", "Admin/Oficial", "sp_RechazarPrestamo"),
    ("POST", "/api/prestamos/{numero}/amortizacion", "Admin/Oficial", "sp_GenerarAmortizacion"),
    ("POST", "/api/prestamos/{numero}/cuotas/{n}/pagos", "Admin/Cajero", "sp_PagarCuota"),
    ("GET", "/api/clientes-morosos", "Admin/Oficial", "sp_BuscarClientesMorosos"),
    ("GET", "/api/cartera/dashboard", "Admin/Oficial", "sp_ConsultarDashboardCartera"),
    ("GET", "/api/productos-financieros", "Autenticado", "sp_BuscarProductosFinancieros"),
    ("POST/PUT", "/api/productos-financieros", "Admin", "sp_GuardarProductoFinanciero"),
    ("GET", "/api/cobranza/alertas", "Admin/Oficial", "sp_ConsultarAlertasCobranza"),
    ("POST", "/api/cobranza/gestiones", "Admin/Oficial", "sp_RegistrarGestionCobranza"),
    ("GET", "/api/auditoria", "Admin/Auditor", "sp_ConsultarAuditoria"),
]


def add_section(story, title: str, intro: str | None = None):
    story.append(PageBreak())
    story.append(Paragraph(title, STYLES["Heading1"]))
    if intro:
        story.append(p(intro))


def build_story(repo: Path):
    story = []

    story.extend(
        [
            Spacer(1, 1.05 * inch),
            p("BTI23 BASES DE DATOS II", "Callout"),
            Spacer(1, 0.35 * inch),
            Paragraph("COOPCORE", ParagraphStyle("Cover", fontName=FONT_BOLD, fontSize=38, leading=43, textColor=NAVY, alignment=TA_CENTER)),
            Spacer(1, 0.16 * inch),
            Paragraph("Manual tecnico de entrega final", ParagraphStyle("CoverSub", fontName=FONT, fontSize=19, leading=24, textColor=BLUE, alignment=TA_CENTER)),
            Spacer(1, 0.55 * inch),
            Table(
                [
                    [p("Version", "Small"), p("1.0 final", "Small")],
                    [p("Fecha", "Small"), p("17 de agosto de 2026", "Small")],
                    [p("Repositorio", "Small"), p("github.com/LLULIAN17/CoopCore", "Small")],
                    [p("Esquema", "Small"), p("SQL Server · CoopCoreDB · coop", "Small")],
                    [p("Equipo", "Small"), p("Equipo CoopCore", "Small")],
                ],
                colWidths=[1.35 * inch, 4.65 * inch],
                style=TableStyle(
                    [
                        ("GRID", (0, 0), (-1, -1), 0.5, LINE),
                        ("BACKGROUND", (0, 0), (0, -1), NAVY),
                        ("TEXTCOLOR", (0, 0), (0, -1), WHITE),
                        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                        ("TOPPADDING", (0, 0), (-1, -1), 8),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                    ]
                ),
            ),
            Spacer(1, 0.65 * inch),
            p(
                "Documento consolidado de arquitectura, modelo de datos, seguridad, procedimientos, "
                "transacciones, optimizacion, API, instalacion y pruebas.",
                "Caption",
            ),
        ]
    )

    add_section(story, "Control documental y contenido")
    story.append(
        table(
            [
                ["Version", "Fecha", "Responsable", "Cambio"],
                ["1.0", "2026-08-17", "Equipo CoopCore", "Consolidacion para entrega final."],
            ],
            [0.7 * inch, 1.0 * inch, 1.45 * inch, 3.65 * inch],
            small=True,
        )
    )
    story.append(Spacer(1, 0.18 * inch))
    toc = TableOfContents()
    toc.levelStyles = [
        ParagraphStyle("TOC1", fontName=FONT_BOLD, fontSize=10, leading=15, leftIndent=0, textColor=NAVY),
        ParagraphStyle("TOC2", fontName=FONT, fontSize=8.5, leading=12, leftIndent=18, textColor=MUTED),
    ]
    story.append(toc)

    add_section(
        story,
        "1. Resumen ejecutivo",
        "CoopCore es una plataforma academica para una cooperativa de ahorro y credito. "
        "Su objetivo es demostrar que SQL Server puede concentrar reglas de negocio, "
        "seguridad, consistencia transaccional, auditoria y optimizacion, mientras una API "
        "REST y un frontend web actuan como canales de acceso controlados.",
    )
    story.extend(
        bullet(
            [
                "10 tablas normalizadas dentro del esquema funcional coop.",
                "24 stored procedures con SET NOCOUNT ON, autor, fecha y manejo de errores.",
                "2 funciones SQL utilizadas por procedimientos existentes.",
                "10 procedimientos con transacciones explicitas y ROLLBACK seguro.",
                "5 roles SQL y 5 logins de laboratorio con minimo privilegio.",
                "API .NET 10 con JWT, autorizacion por rol y errores consistentes.",
                "Frontend Next.js para cartera, morosidad, productos y cobranza.",
                "5 indices evaluados con costos y planes XML antes/despues.",
            ]
        )
    )
    story.append(p("La idea SaaS", "Heading2"))
    story.append(
        p(
            "La propuesta SaaS permite que cooperativas pequenas operen una plataforma centralizada sin "
            "mantener logica financiera duplicada en cada cliente. La separacion por capas facilita "
            "desplegar la API y la interfaz de forma independiente, pero conserva una fuente unica de verdad "
            "en SQL Server. En una evolucion comercial, cada organizacion tendria aislamiento de datos, "
            "configuracion de productos, monitoreo, copias de seguridad y politicas de retencion propias."
        )
    )

    add_section(story, "2. Arquitectura de solucion")
    story.append(ArchitectureDiagram(6.85 * inch))
    story.append(p("Responsabilidades", "Heading2"))
    story.append(
        table(
            [
                ["Capa", "Responsabilidad", "Tecnologia"],
                ["Frontend", "Interaccion, filtros, formularios y visualizacion.", "Next.js / React / TypeScript"],
                ["API", "Autenticacion JWT, autorizacion, validacion minima y serializacion.", ".NET 10 / ASP.NET Core / ADO.NET"],
                ["Base de datos", "Reglas, transacciones, permisos, auditoria y calculos.", "SQL Server / T-SQL"],
            ],
            [1.0 * inch, 3.9 * inch, 1.95 * inch],
            small=True,
        )
    )
    story.append(p("Principio rector", "Heading2"))
    story.append(p("La API no reemplaza las reglas financieras. Cada operacion relevante invoca un stored procedure del esquema coop. Esto reduce divergencias entre clientes, centraliza el control de concurrencia y permite auditar la operacion en la misma transaccion."))

    add_section(story, "3. Dominio funcional")
    modules = [
        ("Autenticacion", "Login, cambio de clave, bloqueo temporal y JWT."),
        ("Socios", "Registro y consulta del asociado."),
        ("Cuentas", "Apertura, saldo, deposito, retiro y transferencia."),
        ("Prestamos", "Solicitud, aprobacion, rechazo, amortizacion y pago."),
        ("Morosidad", "Busqueda, clasificacion y monto vencido."),
        ("Cartera", "Indicadores, riesgo y proximos vencimientos."),
        ("Productos", "Catalogo de ahorro, prestamos y certificados."),
        ("Cobranza", "Alertas, compromisos y seguimiento."),
        ("Auditoria", "Trazabilidad de acceso y operaciones."),
    ]
    story.append(table([["Modulo", "Alcance"]] + modules, [1.45 * inch, 5.4 * inch], small=True))
    story.append(p("Reglas principales", "Heading2"))
    story.extend(
        bullet(
            [
                "Los saldos de cuenta nunca pueden ser negativos.",
                "Los movimientos contables son inmutables mediante trigger.",
                "Una transferencia registra salida y entrada con la misma referencia.",
                "Un pago no supera el pendiente de la cuota ni el saldo del prestamo.",
                "Las cuotas vencidas se calculan a una fecha de corte explicita.",
                "Cada escritura relevante genera un evento de auditoria.",
            ]
        )
    )

    add_section(story, "4. Diagrama entidad-relacion final")
    story.append(ERDiagram(6.85 * inch))
    story.append(p("Figura 1. Modelo ER logico del esquema coop. Las relaciones son 1:N y se implementan mediante llaves foraneas.", "Caption"))
    story.append(p("Control de aprobacion docente: pendiente de validacion externa. El equipo debe presentar esta pagina al docente y registrar fecha o firma sin alterar el modelo aprobado.", "Callout"))

    add_section(
        story,
        "5. Diccionario de datos",
        "El diccionario se deriva de sql/01_schema_tables.sql y sql/15_alertas_cobranza.sql. "
        "Abreviaturas: PK llave primaria; FK llave foranea; UQ unicidad; CK validacion; "
        "DF valor predeterminado; NN no admite NULL.",
    )
    overview = [["Tabla", "Columnas", "Proposito"]]
    purposes = {
        "coop.Socio": "Personas asociadas.",
        "coop.Rol": "Roles funcionales de aplicacion.",
        "coop.Empleado": "Operadores y credenciales.",
        "coop.ProductoFinanciero": "Catalogo de productos.",
        "coop.Cuenta": "Cuentas y saldos.",
        "coop.Prestamo": "Creditos y estado.",
        "coop.Cuota": "Calendario de pagos.",
        "coop.Movimiento": "Bitacora monetaria inmutable.",
        "coop.Auditoria": "Trazabilidad general.",
        "coop.GestionCobranza": "Seguimiento de cobro.",
    }
    for name, columns in DATA_DICTIONARY.items():
        overview.append([name, str(len(columns)), purposes[name]])
    story.append(table(overview, [2.2 * inch, 0.8 * inch, 3.85 * inch], small=True))

    for number_index, (table_name, columns) in enumerate(DATA_DICTIONARY.items(), start=1):
        story.append(PageBreak())
        story.append(Paragraph(f"5.{number_index} {table_name}", STYLES["Heading2"]))
        story.append(p(purposes[table_name]))
        rows = [["Columna", "Tipo", "Restricciones", "Descripcion"]] + [list(row) for row in columns]
        story.append(table(rows, [1.55 * inch, 1.25 * inch, 1.15 * inch, 2.9 * inch], small=True))

    add_section(story, "6. Objetos programables SQL")
    story.append(p("Funciones", "Heading2"))
    story.append(
        table(
            [
                ["Funcion", "Tipo", "Uso real"],
                ["coop.fn_CalcularMoraCuota", "Escalar", "sp_ConsultarAlertasCobranza y funcion tabular."],
                ["coop.fn_ObtenerCuotasVencidas", "Tabla en linea", "sp_BuscarClientesMorosos y sp_ConsultarDashboardCartera."],
            ],
            [2.4 * inch, 1.0 * inch, 3.45 * inch],
            small=True,
        )
    )
    story.append(p("Stored procedures", "Heading2"))
    story.append(table([["Procedimiento", "Responsabilidad"]] + PROCEDURES, [2.75 * inch, 4.1 * inch], small=True))
    story.append(p("Parametros OUTPUT", "Heading2"))
    story.extend(
        bullet(
            [
                "sp_RegistrarDeposito: @NuevoSaldo y @NuevoMovimientoID.",
                "sp_RegistrarTransferencia: @MovimientoSalidaID y @MovimientoEntradaID.",
                "sp_SolicitarPrestamo: @NuevoPrestamoID y @NuevoNumeroPrestamo.",
                "Los parametros tienen valor predeterminado NULL y conservan los result sets consumidos por la API.",
            ]
        )
    )
    story.append(p("Vistas y trigger", "Heading2"))
    story.append(
        table(
            [
                ["Objeto", "Tipo", "Responsabilidad"],
                ["coop.vw_CuentasResumen", "Vista", "Cuenta, socio, producto y saldo."],
                ["coop.vw_MovimientosAuditoria", "Vista", "Movimiento con cuenta, socio y empleado."],
                ["coop.vw_PrestamosResumen", "Vista", "Prestamo con agregados de cuotas."],
                ["coop.vw_SociosConsulta", "Vista", "Socio con cuentas y cartera consolidada."],
                ["coop.tr_Movimiento_Inmutable", "Trigger", "Impide UPDATE y DELETE contable."],
            ],
            [2.45 * inch, 0.85 * inch, 3.55 * inch],
            small=True,
        )
    )
    story.append(
        p(
            "Todos los procedimientos comienzan con SET NOCOUNT ON. Las operaciones criticas usan "
            "TRY/CATCH y devuelven result sets, codigos de estado o parametros OUTPUT segun corresponda."
        )
    )

    add_section(story, "7. Transacciones explicitas y concurrencia")
    story.append(p("Patron transaccional", "Heading2"))
    story.append(
        p(
            "Los procedimientos monetarios activan SET XACT_ABORT ON, abren una transaccion dentro de BEGIN TRY, "
            "validan filas bloqueadas con UPDLOCK y HOLDLOCK, escriben las tablas de negocio y auditoria, y solo "
            "entonces confirman. BEGIN CATCH revierte cuando @@TRANCOUNT es mayor que cero y relanza un error de dominio."
        )
    )
    story.append(code("SET XACT_ABORT ON;\nBEGIN TRY\n    BEGIN TRANSACTION;\n    -- validaciones, bloqueos, escritura y auditoria\n    COMMIT TRANSACTION;\nEND TRY\nBEGIN CATCH\n    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;\n    THROW;\nEND CATCH;"))
    transaction_rows = [["Procedimiento", "Tablas atomicas", "Control especial"]]
    transaction_rows += [
        ["Deposito", "Cuenta, Movimiento, Auditoria", "UPDLOCK/HOLDLOCK"],
        ["Retiro", "Cuenta, Movimiento, Auditoria", "Saldo suficiente"],
        ["Transferencia", "2 Cuenta, 2 Movimiento, Auditoria", "Orden estable de bloqueos"],
        ["Pago de cuota", "Cuenta, Cuota, Prestamo, Movimiento, Auditoria", "Limites de pago"],
        ["Solicitud", "Prestamo, Auditoria", "Numero unico"],
        ["Aprobacion/Rechazo", "Prestamo, Auditoria", "Estado esperado"],
        ["Amortizacion", "Cuota, Auditoria", "Sin cuotas previas"],
        ["Producto/Cobranza", "Objeto, Auditoria", "TRY/CATCH y rollback"],
    ]
    story.append(table(transaction_rows, [1.4 * inch, 3.0 * inch, 2.45 * inch], small=True))

    add_section(story, "8. Control de acceso y seguridad")
    security = [
        ["Rol SQL", "Perfil", "Acceso principal"],
        ["rol_admin_coop", "Administrador", "Todos los SPs operativos."],
        ["rol_cajero_coop", "Caja", "Socios, cuentas, movimientos y pagos."],
        ["rol_oficial_credito_coop", "Credito", "Prestamos, mora, cartera y cobranza."],
        ["rol_auditor_coop", "Auditoria", "Consultas y vistas; escritura denegada."],
        ["rol_api_coop", "Servicio", "Solo SPs usados por la API; sin tablas directas."],
    ]
    story.append(table(security, [1.7 * inch, 1.45 * inch, 3.7 * inch], small=True))
    story.append(p("Defensa en profundidad", "Heading2"))
    story.extend(
        bullet(
            [
                "Logins y usuarios separados por perfil.",
                "Permisos EXECUTE por objeto y DENY de escritura directa.",
                "Passwords de aplicacion almacenadas con salt y SHA2_256.",
                "Bloqueo temporal despues de cinco intentos fallidos.",
                "JWT con vigencia de 60 minutos y rol de aplicacion.",
                "La cadena de conexion real permanece fuera del repositorio.",
                "Las credenciales seed son exclusivamente academicas.",
            ]
        )
    )

    add_section(story, "9. API REST .NET 10")
    story.append(p("La API sigue Controllers -> Interfaces -> Services -> Db. SqlExecutor crea SqlCommand con CommandType.StoredProcedure y transforma filas a modelos de respuesta. Los controladores aplican autorizacion por rol y producen ApiResponse uniforme."))
    endpoint_rows = [["Metodo", "Ruta", "Rol", "Stored procedure"]] + [list(row) for row in ENDPOINTS]
    story.append(table(endpoint_rows, [0.65 * inch, 2.75 * inch, 1.2 * inch, 2.25 * inch], small=True))

    add_section(story, "10. Autenticacion, errores y uso del API")
    story.append(p("Flujo JWT", "Heading2"))
    story.extend(
        bullet(
            [
                "El cliente envia usuario y password a POST /api/auth/login.",
                "sp_ValidarLogin verifica hash, estado y bloqueo y registra auditoria.",
                "La API emite un JWT firmado con usuario, empleado y rol.",
                "El cliente envia Authorization: Bearer TOKEN en cada ruta protegida.",
                "La politica de ASP.NET Core devuelve 401 sin identidad y 403 sin rol.",
            ]
        )
    )
    story.append(code('curl.exe -X POST http://localhost:5000/api/auth/login `\n  -H "Content-Type: application/json" `\n  -d \'{"usuario":"mlrojas","password":"Lab_Cajero_001"}\'\n\n$token = "<datos.token>"\ncurl.exe http://localhost:5000/api/cuentas/CTA-10001/saldo `\n  -H "Authorization: Bearer $token"'))
    story.append(p("Contrato de errores", "Heading2"))
    story.append(table([["HTTP", "Situacion"], ["400", "Validacion o regla de negocio."], ["401", "Token ausente, invalido o vencido."], ["403", "Rol insuficiente."], ["404", "Recurso no encontrado."], ["500", "Error no controlado, sin exponer secretos."]], [1.0 * inch, 5.85 * inch], small=True))

    add_section(story, "11. Analisis y optimizacion")
    story.append(p("Metodologia", "Heading2"))
    story.extend(
        bullet(
            [
                "Linea base con SET STATISTICS IO/TIME antes de crear indices.",
                "Cinco indices vinculados a patrones reales de acceso.",
                "Planes XML estimados antes y despues sobre la misma instancia y seed.",
                "DROP/CREATE de cada indice dentro de una transaccion que se revierte.",
                "Comparacion de costo, operadores, indice elegido y lecturas logicas.",
            ]
        )
    )
    costs = [
        ["Indice", "Costo antes", "Costo despues", "Delta"],
        ["Movimiento_Cuenta_Fecha", "0.01467280", "0.00328680", "-77.60%"],
        ["Cuenta_Socio_Saldo", "0.00328942", "0.00328420", "-0.16%"],
        ["Prestamo_Socio_Saldo", "0.00328942", "0.00328420", "-0.16%"],
        ["Cuota_Prestamo_Numero", "0.00730559", "0.00328640", "-55.02%"],
        ["Auditoria_Accion_Fecha", "0.01474430", "0.00330000", "-77.62%"],
    ]
    story.append(p("Comparacion de costos estimados", "Heading2"))
    story.append(table(costs, [2.8 * inch, 1.35 * inch, 1.35 * inch, 1.0 * inch], small=True))

    summary_image = repo / "docs/evidencias/planes/resumen_costos_estimados.png"
    if summary_image.exists():
        story.append(PageBreak())
        story.append(Paragraph("11.1 Comparacion visual consolidada", STYLES["Heading2"]))
        story.append(Image(str(summary_image), width=6.85 * inch, height=3.85 * inch))
        story.append(p("Figura 2. Costo estimado antes y despues. Fuente: planes SHOWPLAN XML versionados en docs/evidencias/planes.", "Caption"))
        story.append(p("Los indices de Cuenta y Prestamo muestran una mejora pequena por el volumen reducido del seed, aunque cambian de Clustered Index Scan a Index Seek. Cuota reduce lecturas de 12 a 4. Movimiento y Auditoria eliminan Sort y usan el indice diseñado."))

    for image_name, heading in [
        ("movimientos_comparacion.png", "11.2 Plan de movimientos"),
        ("cuotas_por_prestamo_comparacion.png", "11.3 Plan de cuotas"),
        ("auditoria_por_accion_comparacion.png", "11.4 Plan de auditoria"),
    ]:
        image_path = repo / "docs/evidencias/planes" / image_name
        if image_path.exists():
            story.append(PageBreak())
            story.append(Paragraph(heading, STYLES["Heading2"]))
            story.append(Image(str(image_path), width=6.85 * inch, height=3.85 * inch))
            story.append(p("Visualizacion derivada del archivo .sqlplan original. El plan completo puede abrirse en SSMS.", "Caption"))

    add_section(story, "12. Instalacion reproducible")
    story.append(p("Requisitos", "Heading2"))
    story.extend(bullet(["SQL Server Express o superior.", "sqlcmd con ODBC Driver 18.", ".NET SDK 10.", "Node.js y npm para el frontend.", "Git y GitHub CLI para colaboracion."]))
    story.append(p("Orden de scripts", "Heading2"))
    order = [
        "00_create_database.sql", "01_schema_tables.sql", "02_seed_data.sql", "03_functions.sql",
        "03_views.sql", "04_stored_procedures.sql", "05_transactions.sql", "06_security.sql",
        "07_security_tests.sql", "08_concurrency_tests.sql", "09_execution_plan_baseline.sql",
        "09_indexes_optimization.sql", "10_revision3_tests.sql", "11_busqueda_clientes_morosos.sql",
        "12_busqueda_clientes_morosos_tests.sql", "13_dashboard_cartera.sql",
        "14_productos_financieros.sql", "15_alertas_cobranza.sql", "16_ampliacion_50_tests.sql",
        "17_entrega_final_tests.sql",
    ]
    story.append(table([["#", "Script"]] + [[str(i), name] for i, name in enumerate(order, 1)], [0.55 * inch, 6.3 * inch], small=True))

    add_section(story, "13. Puesta en marcha de API y frontend")
    story.append(p("API", "Heading2"))
    story.append(code("Copy-Item api\\coopcore-api\\coopcore-api\\appsettings.example.json `\n  api\\coopcore-api\\coopcore-api\\appsettings.Development.json\n\ndotnet restore api\\coopcore-api\\coopcore-api\\coopcore-api.csproj\ndotnet build api\\coopcore-api\\coopcore-api\\coopcore-api.csproj\ndotnet run --project api\\coopcore-api\\coopcore-api\\coopcore-api.csproj `\n  --urls http://localhost:5000"))
    story.append(p("Frontend", "Heading2"))
    story.append(code("Set-Location frontend\\app\nnpm ci\nnpm run lint\nnpm test\nnpm run dev"))
    story.append(p("Para demostrar integracion real, el frontend debe usar la URL de la API y un JWT obtenido por login. Los datos demo sirven como degradacion visual, pero no sustituyen la prueba en vivo con SQL Server."))

    add_section(story, "14. Estrategia de pruebas")
    tests = [
        ["Nivel", "Prueba", "Criterio"],
        ["SQL instalacion", "Secuencia 00 a 17 sobre base nueva", "Todos los scripts terminan con codigo 0."],
        ["SQL funcional", "Funciones y OUTPUT", "Valores esperados y rollback."],
        ["Seguridad", "Roles, grants y denies", "Acceso permitido/denegado segun perfil."],
        ["Concurrencia", "Bloqueos y transacciones", "Sin saldo negativo ni escrituras parciales."],
        ["API compilacion", "dotnet build Release", "0 errores y 0 advertencias."],
        ["API HTTP", "Login, lecturas, escrituras y roles", "200/201, 400, 401 y 403 esperados."],
        ["Frontend", "lint, build y render", "Sin errores y HTML verificable."],
        ["PDF", "Render completo", "20+ paginas sin recortes ni solapamientos."],
    ]
    story.append(table(tests, [1.25 * inch, 2.6 * inch, 3.0 * inch], small=True))
    story.append(p("Pruebas reversibles", "Heading2"))
    story.append(p("Los scripts de revision y entrega final encapsulan operaciones de escritura en transacciones externas y ejecutan ROLLBACK. Esto permite validar identificadores, saldos y auditoria sin contaminar el seed ni dificultar ejecuciones posteriores."))

    add_section(story, "15. Operacion, monitoreo y respaldo")
    story.extend(
        bullet(
            [
                "Monitorear crecimiento de Movimiento, Auditoria, Cuota y GestionCobranza.",
                "Revisar fragmentacion y estadisticas de indices en ventanas planificadas.",
                "Respaldar CoopCoreDB antes de cambios de esquema y comprobar restauracion.",
                "Rotar la clave JWT y las credenciales SQL fuera del codigo fuente.",
                "Consultar errores de la API sin registrar passwords ni tokens completos.",
                "Definir retencion de auditoria conforme a politica institucional.",
            ]
        )
    )
    story.append(p("Recuperacion", "Heading2"))
    story.append(p("Ante una falla se debe detener la escritura, conservar logs, restaurar el ultimo respaldo valido en una instancia aislada, aplicar respaldos diferenciales o de log si existen, ejecutar pruebas de integridad y solo despues redirigir la API. El procedimiento exacto depende del modelo de recuperacion configurado por la organizacion."))

    add_section(story, "16. Guia de demostracion y defensa")
    demo_steps = [
        ["Minuto", "Accion", "Evidencia"],
        ["0-2", "Presentar arquitectura y ER.", "SQL concentra la logica."],
        ["2-4", "Mostrar login y JWT real.", "Auditoria y expiracion."],
        ["4-7", "Deposito o transferencia.", "Saldo, movimientos y OUTPUT."],
        ["7-10", "Prestamo y amortizacion.", "Transaccion y cuotas."],
        ["10-12", "Morosidad, cartera y cobranza.", "Funciones SQL usadas."],
        ["12-14", "Seguridad por rol.", "403 y permisos SQL."],
        ["14-16", "Planes antes/despues.", "Costo y Index Seek."],
        ["16-18", "Preguntas del equipo.", "Cada integrante explica cualquier capa."],
    ]
    story.append(table(demo_steps, [0.75 * inch, 3.15 * inch, 2.95 * inch], small=True))
    story.append(p("Antes de exponer", "Heading2"))
    story.extend(bullet(["SQL Server iniciado y base recien validada.", "API en localhost:5000 y health 200.", "Frontend conectado a la API, no solo a datos demo.", "Usuarios de cada rol probados.", "Planes .sqlplan listos para abrir en SSMS.", "Cada integrante conoce funciones, OUTPUT, transacciones, seguridad y API."]))

    add_section(story, "17. Riesgos, limitaciones y trabajo futuro")
    risks = [
        ["Riesgo o limite", "Tratamiento actual", "Evolucion"],
        ["Seed pequeno", "Comparar operadores y costo ademas de tiempo.", "Pruebas con volumen sintetico."],
        ["SQL Express con autenticacion Windows", "API local usa conexion integrada para pruebas.", "Habilitar modo mixto en despliegue controlado."],
        ["Datos demo del frontend", "Modo degradado identificado.", "Selector explicito API/demo y prueba E2E."],
        ["JWT simetrico", "Clave fuera del repositorio.", "Secret manager y rotacion."],
        ["Sin multi-tenancy", "Modelo para una cooperativa.", "TenantID y aislamiento si se comercializa."],
        ["Aprobacion ER externa", "Diagrama final preparado.", "Registrar aprobacion docente."],
    ]
    story.append(table(risks, [1.65 * inch, 2.55 * inch, 2.65 * inch], small=True))

    add_section(story, "18. Trazabilidad de requisitos")
    trace = [
        ["Requisito", "Implementacion", "Evidencia"],
        ["2 funciones usadas", "03_functions + SPs de mora/cartera", "17_entrega_final_tests.sql"],
        ["Parametros entrada/salida", "3 SPs con OUTPUT opcional", "Pruebas 5, 6 y 7"],
        ["Autor y fecha", "24 cabeceras normalizadas", "Scripts 04, 05, 11, 13, 14 y 15"],
        ["Optimizacion numerica", "5 costos antes/despues", "docs/evidencias/planes"],
        ["Diagrama ER", "10 tablas y relaciones", "Seccion 4"],
        ["Diccionario", "Todas las columnas y restricciones", "Seccion 5"],
        ["Manual 20+ paginas", "PDF consolidado", "Este documento"],
        ["Instalacion limpia", "Secuencia automatizada", "Evidencia sqlcmd"],
        ["Demo real", "Checklist SQL + API + JWT + frontend", "Seccion 16"],
    ]
    story.append(table(trace, [1.65 * inch, 2.75 * inch, 2.45 * inch], small=True))

    add_section(story, "19. Glosario")
    glossary = [
        ["Termino", "Definicion"],
        ["Atomicidad", "Una transaccion confirma todas sus escrituras o ninguna."],
        ["Costo estimado", "Valor relativo calculado por el optimizador para un plan."],
        ["Index Seek", "Acceso dirigido a un rango de claves de un indice."],
        ["JWT", "Token firmado que transporta identidad y claims."],
        ["Mora", "Atraso de una cuota respecto de la fecha de corte."],
        ["OUTPUT", "Parametro mediante el cual un SP devuelve un valor al llamador."],
        ["Ownership chaining", "Resolucion de permisos entre objetos con propietario comun."],
        ["Result set", "Conjunto tabular devuelto por una consulta o procedimiento."],
        ["Rollback", "Reversion de cambios no confirmados."],
        ["Salt", "Valor aleatorio agregado antes de calcular un hash de password."],
        ["Stored procedure", "Programa T-SQL almacenado y ejecutado en la base."],
    ]
    story.append(table(glossary, [1.55 * inch, 5.3 * inch], small=True))

    add_section(story, "20. Referencias internas y cierre")
    story.extend(
        bullet(
            [
                "README.md - instalacion, modulos y endpoints.",
                "sql/01_schema_tables.sql - modelo fisico.",
                "sql/03_functions.sql - funciones de dominio.",
                "sql/04_stored_procedures.sql y sql/05_transactions.sql - operaciones principales.",
                "sql/06_security.sql - logins, usuarios, roles y permisos.",
                "docs/optimizacion_indices.md - comparacion cuantitativa.",
                "docs/evidencias/planes - planes XML, CSV e imagenes.",
                "api/coopcore-api/README.md - configuracion y contrato HTTP.",
                "docs/evidencias/sistema_completo_smoke_test.md - validacion integral.",
            ]
        )
    )
    story.append(p("Conclusion", "Heading2"))
    story.append(p("CoopCore cumple el objetivo academico de mantener la logica de negocio en SQL Server y exponerla de forma segura mediante una API delgada. La entrega final incorpora las funciones requeridas, parametros OUTPUT, cabeceras trazables, comparacion numerica de optimizacion, modelo ER, diccionario de datos y una guia reproducible de instalacion, prueba y defensa."))
    story.append(p("Fin del manual tecnico · Version 1.0", "Callout"))
    return story


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="docs/CoopCore_Manual_Tecnico.pdf")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    output = (repo / args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    document = CoopDocTemplate(
        str(output),
        pagesize=letter,
        leftMargin=0.65 * inch,
        rightMargin=0.65 * inch,
        topMargin=0.68 * inch,
        bottomMargin=0.67 * inch,
        title="CoopCore - Manual tecnico de entrega final",
        author="Equipo CoopCore",
        subject="BTI23 Bases de Datos II",
    )
    document.multiBuild(build_story(repo))
    print(output)


if __name__ == "__main__":
    main()

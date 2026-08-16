"use client";

import { type CSSProperties, type FormEvent, useMemo, useState } from "react";

type ModuleId = "dashboard" | "morosidad" | "productos" | "cobranza";

type DashboardData = {
  fechaCorte: string;
  totalSociosActivos: number;
  totalPrestamosVigentes: number;
  saldoCarteraTotal: number;
  prestamosConMora: number;
  clientesMorosos: number;
  montoVencido: number;
  cuotasVencidas: number;
  indiceMorosidadPct: number;
  distribucionRiesgo: Array<{
    nivelRiesgo: string;
    cantidadClientes: number;
    montoVencido: number;
  }>;
  proximosVencimientos: Array<{
    cedula: string;
    nombreCliente: string;
    numeroPrestamo: string;
    numeroCuota: number;
    fechaVencimiento: string;
    montoPendiente: number;
    diasParaVencer: number;
  }>;
};

type Moroso = {
  socioId: number;
  cedula: string;
  nombreCompleto: string;
  telefono?: string;
  prestamos: string[];
  cantidadCuotasVencidas: number;
  diasMoraMaximos: number;
  nivelRiesgo: string;
  montoTotalMora: number;
};

type Product = {
  productoFinancieroId: number;
  codigoProducto: string;
  nombreProducto: string;
  tipoProducto: string;
  tasaInteres: number;
  montoMinimoApertura: number;
  estado: string;
  cantidadCuentas: number;
  cantidadPrestamos: number;
  saldoCartera: number;
};

type Alert = {
  cuotaId: number;
  cedula: string;
  nombreCliente: string;
  telefono?: string;
  numeroPrestamo: string;
  numeroCuota: number;
  fechaVencimiento: string;
  montoPendiente: number;
  tipoAlerta: string;
  prioridad: string;
  diasMora: number;
  diasParaVencer: number;
  ultimaGestionResultado?: string;
};

const demoDashboard: DashboardData = {
  fechaCorte: "2026-02-01",
  totalSociosActivos: 4,
  totalPrestamosVigentes: 1,
  saldoCarteraTotal: 3200,
  prestamosConMora: 1,
  clientesMorosos: 1,
  montoVencido: 300,
  cuotasVencidas: 2,
  indiceMorosidadPct: 9.38,
  distribucionRiesgo: [
    { nivelRiesgo: "MEDIO", cantidadClientes: 1, montoVencido: 300 },
  ],
  proximosVencimientos: [
    {
      cedula: "SO-1004",
      nombreCliente: "Valeria Campos",
      numeroPrestamo: "PR-26001",
      numeroCuota: 2,
      fechaVencimiento: "2026-02-08",
      montoPendiente: 100,
      diasParaVencer: 7,
    },
    {
      cedula: "SO-1001",
      nombreCliente: "Andrea Solano",
      numeroPrestamo: "PR-26002",
      numeroCuota: 1,
      fechaVencimiento: "2026-02-15",
      montoPendiente: 185,
      diasParaVencer: 14,
    },
  ],
};

const demoMorosos: Moroso[] = [
  {
    socioId: 2,
    cedula: "SO-1002",
    nombreCompleto: "Diego Alvarado",
    telefono: "8888-1002",
    prestamos: ["PR-20001"],
    cantidadCuotasVencidas: 2,
    diasMoraMaximos: 48,
    nivelRiesgo: "MEDIO",
    montoTotalMora: 300,
  },
];

const demoProducts: Product[] = [
  {
    productoFinancieroId: 1,
    codigoProducto: "AHO_BASICO",
    nombreProducto: "Cuenta Ahorro Básico",
    tipoProducto: "AHORRO",
    tasaInteres: 1.5,
    montoMinimoApertura: 100,
    estado: "ACTIVO",
    cantidadCuentas: 3,
    cantidadPrestamos: 0,
    saldoCartera: 0,
  },
  {
    productoFinancieroId: 2,
    codigoProducto: "AHO_JUVENIL",
    nombreProducto: "Cuenta Ahorro Juvenil",
    tipoProducto: "AHORRO",
    tasaInteres: 2.25,
    montoMinimoApertura: 50,
    estado: "ACTIVO",
    cantidadCuentas: 1,
    cantidadPrestamos: 0,
    saldoCartera: 0,
  },
  {
    productoFinancieroId: 3,
    codigoProducto: "PRE_CONSUMO",
    nombreProducto: "Préstamo Personal Consumo",
    tipoProducto: "PRESTAMO",
    tasaInteres: 14.75,
    montoMinimoApertura: 0,
    estado: "ACTIVO",
    cantidadCuentas: 0,
    cantidadPrestamos: 2,
    saldoCartera: 3200,
  },
];

const demoAlerts: Alert[] = [
  {
    cuotaId: 3,
    cedula: "SO-1002",
    nombreCliente: "Diego Alvarado",
    telefono: "8888-1002",
    numeroPrestamo: "PR-20001",
    numeroCuota: 3,
    fechaVencimiento: "2025-12-15",
    montoPendiente: 50,
    tipoAlerta: "VENCIDA",
    prioridad: "ALTA",
    diasMora: 48,
    diasParaVencer: 0,
    ultimaGestionResultado: "CONTACTADO",
  },
  {
    cuotaId: 4,
    cedula: "SO-1002",
    nombreCliente: "Diego Alvarado",
    telefono: "8888-1002",
    numeroPrestamo: "PR-20001",
    numeroCuota: 4,
    fechaVencimiento: "2026-01-15",
    montoPendiente: 250,
    tipoAlerta: "VENCIDA",
    prioridad: "MEDIA",
    diasMora: 17,
    diasParaVencer: 0,
  },
];

const modules: Array<{ id: ModuleId; label: string; short: string }> = [
  { id: "dashboard", label: "Resumen de cartera", short: "RC" },
  { id: "morosidad", label: "Clientes morosos", short: "CM" },
  { id: "productos", label: "Productos", short: "PF" },
  { id: "cobranza", label: "Cobranza", short: "CO" },
];

const currency = new Intl.NumberFormat("es-CR", {
  style: "currency",
  currency: "CRC",
  maximumFractionDigits: 0,
});

const displayDate = (value: string) =>
  new Intl.DateTimeFormat("es-CR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(new Date(`${value.slice(0, 10)}T12:00:00`));

export function CoopCoreDashboard() {
  const [active, setActive] = useState<ModuleId>("dashboard");
  const [dashboard, setDashboard] = useState(demoDashboard);
  const [morosos, setMorosos] = useState(demoMorosos);
  const [products, setProducts] = useState(demoProducts);
  const [alerts, setAlerts] = useState(demoAlerts);
  const [query, setQuery] = useState("");
  const [apiUrl, setApiUrl] = useState("http://localhost:5000");
  const [token, setToken] = useState("");
  const [connectionOpen, setConnectionOpen] = useState(false);
  const [connectionState, setConnectionState] = useState<
    "demo" | "loading" | "live" | "error"
  >("demo");
  const [notice, setNotice] = useState("");
  const [productFormOpen, setProductFormOpen] = useState(false);
  const [managementOpen, setManagementOpen] = useState(false);
  const [selectedAlert, setSelectedAlert] = useState<Alert | null>(null);

  const filteredMorosos = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return morosos;
    return morosos.filter((item) =>
      [item.cedula, item.nombreCompleto, ...item.prestamos].some((value) =>
        value.toLowerCase().includes(term),
      ),
    );
  }, [morosos, query]);

  const filteredProducts = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return products;
    return products.filter((item) =>
      [item.codigoProducto, item.nombreProducto, item.tipoProducto].some((value) =>
        value.toLowerCase().includes(term),
      ),
    );
  }, [products, query]);

  async function fetchApi<T>(path: string, options?: RequestInit): Promise<T> {
    const response = await fetch(`${apiUrl.replace(/\/$/, "")}${path}`, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
        ...options?.headers,
      },
    });
    const payload = await response.json();
    if (!response.ok || payload.ok === false) {
      throw new Error(payload.mensaje ?? `La API respondió ${response.status}.`);
    }
    return payload.datos as T;
  }

  async function connectApi() {
    if (!token.trim()) {
      setConnectionState("error");
      setNotice("Ingresa un token de ADMIN_APP u OFICIAL_CREDITO_APP.");
      return;
    }
    setConnectionState("loading");
    setNotice("");
    try {
      const [nextDashboard, morosity, nextProducts, collection] = await Promise.all([
        fetchApi<DashboardData>("/api/cartera/dashboard"),
        fetchApi<{ clientes: Moroso[] }>(
          "/api/clientes-morosos?pagina=1&tamanoPagina=100",
        ),
        fetchApi<Product[]>("/api/productos-financieros"),
        fetchApi<{ alertas: Alert[] }>("/api/cobranza/alertas?diasProximos=30"),
      ]);
      setDashboard(nextDashboard);
      setMorosos(morosity.clientes);
      setProducts(nextProducts);
      setAlerts(collection.alertas);
      setConnectionState("live");
      setConnectionOpen(false);
      setNotice("Datos sincronizados con CoopCore API.");
    } catch (error) {
      setConnectionState("error");
      setNotice(error instanceof Error ? error.message : "No se pudo conectar con la API.");
    }
  }

  async function saveProduct(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const body = {
      codigoProducto: data.get("codigoProducto"),
      nombreProducto: data.get("nombreProducto"),
      tipoProducto: data.get("tipoProducto"),
      tasaInteres: Number(data.get("tasaInteres")),
      montoMinimoApertura: Number(data.get("montoMinimoApertura")),
      estado: "ACTIVO",
      cedulaEmpleado: data.get("cedulaEmpleado"),
    };

    if (connectionState === "live") {
      await fetchApi("/api/productos-financieros", {
        method: "POST",
        body: JSON.stringify(body),
      });
      await connectApi();
    } else {
      setProducts((current) => [
        ...current,
        {
          productoFinancieroId: Date.now(),
          codigoProducto: String(body.codigoProducto),
          nombreProducto: String(body.nombreProducto),
          tipoProducto: String(body.tipoProducto),
          tasaInteres: body.tasaInteres,
          montoMinimoApertura: body.montoMinimoApertura,
          estado: "ACTIVO",
          cantidadCuentas: 0,
          cantidadPrestamos: 0,
          saldoCartera: 0,
        },
      ]);
    }
    setProductFormOpen(false);
    setNotice("Producto financiero guardado correctamente.");
  }

  async function saveManagement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedAlert) return;
    const data = new FormData(event.currentTarget);
    const body = {
      numeroPrestamo: selectedAlert.numeroPrestamo,
      cedulaEmpleado: data.get("cedulaEmpleado"),
      tipoGestion: data.get("tipoGestion"),
      resultado: data.get("resultado"),
      comentario: data.get("comentario"),
      fechaCompromiso: data.get("fechaCompromiso") || null,
      montoCompromiso: data.get("montoCompromiso")
        ? Number(data.get("montoCompromiso"))
        : null,
    };

    if (connectionState === "live") {
      await fetchApi("/api/cobranza/gestiones", {
        method: "POST",
        body: JSON.stringify(body),
      });
      await connectApi();
    }
    setManagementOpen(false);
    setNotice(`Gestión registrada para ${selectedAlert.numeroPrestamo}.`);
  }

  function selectModule(module: ModuleId) {
    setActive(module);
    setQuery("");
    setNotice("");
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand-mark" aria-label="CoopCore">
          <span>CC</span>
          <div>
            <strong>CoopCore</strong>
            <small>Operaciones</small>
          </div>
        </div>
        <p className="nav-caption">Módulos ampliados</p>
        <nav aria-label="Navegación principal">
          {modules.map((module) => (
            <button
              className={active === module.id ? "nav-item active" : "nav-item"}
              key={module.id}
              onClick={() => selectModule(module.id)}
              type="button"
            >
              <span className="nav-icon">{module.short}</span>
              <span>{module.label}</span>
            </button>
          ))}
        </nav>
        <div className="sidebar-footer">
          <span className={`status-dot ${connectionState}`} />
          <div>
            <strong>{connectionState === "live" ? "API conectada" : "Modo demostración"}</strong>
            <small>Actualizado 15 ago 2026</small>
          </div>
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">Centro de operaciones</p>
            <h1>{modules.find((module) => module.id === active)?.label}</h1>
          </div>
          <div className="topbar-actions">
            <span className="date-pill">15 AGO 2026</span>
            <button
              className="secondary-button"
              type="button"
              onClick={() => setConnectionOpen((open) => !open)}
            >
              {connectionState === "live" ? "Sincronizar" : "Conectar API"}
            </button>
          </div>
        </header>

        {connectionOpen && (
          <section className="connection-panel" aria-label="Conexión con CoopCore API">
            <label>
              URL de la API
              <input value={apiUrl} onChange={(event) => setApiUrl(event.target.value)} />
            </label>
            <label>
              Token Bearer
              <input
                type="password"
                value={token}
                onChange={(event) => setToken(event.target.value)}
                placeholder="Pegue el JWT aquí"
              />
            </label>
            <button
              className="primary-button"
              type="button"
              onClick={connectApi}
              disabled={connectionState === "loading"}
            >
              {connectionState === "loading" ? "Conectando…" : "Cargar datos reales"}
            </button>
          </section>
        )}

        {notice && (
          <div className={connectionState === "error" ? "notice error" : "notice"}>
            {notice}
          </div>
        )}

        {active === "dashboard" && (
          <DashboardView dashboard={dashboard} onOpenMorosity={() => selectModule("morosidad")} />
        )}

        {active === "morosidad" && (
          <section className="content-stack">
            <div className="section-toolbar">
              <div>
                <p className="eyebrow">Cartera vencida</p>
                <h2>Clientes que requieren seguimiento</h2>
              </div>
              <label className="search-field">
                <span>Buscar</span>
                <input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="Cédula, nombre o préstamo"
                />
              </label>
            </div>
            <div className="debtor-grid">
              {filteredMorosos.map((item) => (
                <article className="debtor-card" key={item.socioId}>
                  <div className="card-row">
                    <span className={`risk-badge ${item.nivelRiesgo.toLowerCase()}`}>
                      {item.nivelRiesgo}
                    </span>
                    <span>{item.diasMoraMaximos} días</span>
                  </div>
                  <h3>{item.nombreCompleto}</h3>
                  <p>{item.cedula} · {item.telefono ?? "Sin teléfono"}</p>
                  <div className="debtor-amount">
                    <small>Monto vencido</small>
                    <strong>{currency.format(item.montoTotalMora)}</strong>
                  </div>
                  <div className="card-row detail">
                    <span>{item.cantidadCuotasVencidas} cuotas</span>
                    <span>{item.prestamos.join(", ")}</span>
                  </div>
                  <button className="text-button" type="button" onClick={() => selectModule("cobranza")}>
                    Abrir seguimiento →
                  </button>
                </article>
              ))}
            </div>
          </section>
        )}

        {active === "productos" && (
          <section className="content-stack">
            <div className="section-toolbar">
              <div>
                <p className="eyebrow">Catálogo financiero</p>
                <h2>{products.length} productos configurados</h2>
              </div>
              <div className="toolbar-inline">
                <label className="search-field compact">
                  <span>Buscar</span>
                  <input
                    value={query}
                    onChange={(event) => setQuery(event.target.value)}
                    placeholder="Código o nombre"
                  />
                </label>
                <button className="primary-button" type="button" onClick={() => setProductFormOpen(true)}>
                  Nuevo producto
                </button>
              </div>
            </div>
            <div className="table-card">
              <table>
                <thead>
                  <tr><th>Producto</th><th>Tipo</th><th>Tasa</th><th>Uso</th><th>Cartera</th><th>Estado</th></tr>
                </thead>
                <tbody>
                  {filteredProducts.map((product) => (
                    <tr key={product.productoFinancieroId}>
                      <td><strong>{product.nombreProducto}</strong><small>{product.codigoProducto}</small></td>
                      <td>{product.tipoProducto}</td>
                      <td>{product.tasaInteres.toFixed(2)}%</td>
                      <td>
                        {product.tipoProducto === "PRESTAMO"
                          ? `${product.cantidadPrestamos} préstamos`
                          : `${product.cantidadCuentas} cuentas`}
                      </td>
                      <td>{currency.format(product.saldoCartera)}</td>
                      <td><span className={`state-badge ${product.estado.toLowerCase()}`}>{product.estado}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {productFormOpen && (
              <ProductForm onSubmit={saveProduct} onClose={() => setProductFormOpen(false)} />
            )}
          </section>
        )}

        {active === "cobranza" && (
          <section className="content-stack">
            <div className="section-toolbar">
              <div>
                <p className="eyebrow">Bandeja priorizada</p>
                <h2>{alerts.length} alertas requieren atención</h2>
              </div>
              <div className="alert-summary">
                <span>{alerts.filter((item) => item.tipoAlerta === "VENCIDA").length} vencidas</span>
                <strong>{currency.format(alerts.reduce((sum, item) => sum + item.montoPendiente, 0))}</strong>
              </div>
            </div>
            <div className="collection-list">
              {alerts.map((alert) => (
                <article className="collection-item" key={alert.cuotaId}>
                  <div className={`priority-marker ${alert.prioridad.toLowerCase()}`} />
                  <div className="client-cell">
                    <strong>{alert.nombreCliente}</strong>
                    <small>{alert.cedula} · {alert.telefono ?? "Sin teléfono"}</small>
                  </div>
                  <div><small>Préstamo / cuota</small><strong>{alert.numeroPrestamo} · #{alert.numeroCuota}</strong></div>
                  <div>
                    <small>Vencimiento</small>
                    <strong>{displayDate(alert.fechaVencimiento)}</strong>
                    <span className="overdue-text">
                      {alert.diasMora ? `${alert.diasMora} días de mora` : `vence en ${alert.diasParaVencer} días`}
                    </span>
                  </div>
                  <div className="amount-cell"><small>Pendiente</small><strong>{currency.format(alert.montoPendiente)}</strong></div>
                  <button
                    className="secondary-button small"
                    type="button"
                    onClick={() => { setSelectedAlert(alert); setManagementOpen(true); }}
                  >
                    Registrar gestión
                  </button>
                </article>
              ))}
            </div>
            {managementOpen && selectedAlert && (
              <ManagementForm
                alert={selectedAlert}
                onSubmit={saveManagement}
                onClose={() => setManagementOpen(false)}
              />
            )}
          </section>
        )}
      </section>
    </main>
  );
}

function DashboardView({
  dashboard,
  onOpenMorosity,
}: {
  dashboard: DashboardData;
  onOpenMorosity: () => void;
}) {
  const maxRisk = Math.max(
    ...dashboard.distribucionRiesgo.map((item) => item.montoVencido),
    1,
  );
  const healthStyle = {
    "--health": `${Math.max(100 - dashboard.indiceMorosidadPct, 0) * 3.6}deg`,
  } as CSSProperties;

  return (
    <section className="content-stack">
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Corte {displayDate(dashboard.fechaCorte)}</p>
          <h2>La cartera mantiene una exposición controlada</h2>
          <p>Monitorea saldos, mora y vencimientos desde una sola vista operativa.</p>
        </div>
        <button className="primary-button" type="button" onClick={onOpenMorosity}>
          Revisar morosidad
        </button>
      </div>
      <div className="metric-grid">
        <Metric label="Cartera total" value={currency.format(dashboard.saldoCarteraTotal)} meta={`${dashboard.totalPrestamosVigentes} préstamos vigentes`} tone="ink" />
        <Metric label="Monto vencido" value={currency.format(dashboard.montoVencido)} meta={`${dashboard.cuotasVencidas} cuotas vencidas`} tone="amber" />
        <Metric label="Índice de mora" value={`${dashboard.indiceMorosidadPct.toFixed(2)}%`} meta={`${dashboard.clientesMorosos} clientes afectados`} tone="red" />
        <Metric label="Socios activos" value={String(dashboard.totalSociosActivos)} meta="Base cooperativa" tone="green" />
      </div>
      <div className="dashboard-grid">
        <article className="panel risk-panel">
          <div className="panel-heading">
            <div><p className="eyebrow">Exposición</p><h3>Riesgo por antigüedad</h3></div>
            <span className="quiet-pill">{dashboard.clientesMorosos} clientes</span>
          </div>
          <div className="risk-list">
            {dashboard.distribucionRiesgo.map((risk) => (
              <div className="risk-row" key={risk.nivelRiesgo}>
                <div className="risk-label">
                  <span className={`risk-dot ${risk.nivelRiesgo.toLowerCase()}`} />
                  <strong>{risk.nivelRiesgo}</strong>
                  <small>{risk.cantidadClientes} cliente(s)</small>
                </div>
                <div className="risk-track">
                  <span style={{ width: `${Math.max((risk.montoVencido / maxRisk) * 100, 8)}%` }} />
                </div>
                <strong>{currency.format(risk.montoVencido)}</strong>
              </div>
            ))}
          </div>
        </article>
        <article className="panel health-panel">
          <p className="eyebrow">Salud de cartera</p>
          <div className="health-ring" style={healthStyle}>
            <div><strong>{(100 - dashboard.indiceMorosidadPct).toFixed(1)}%</strong><small>al día</small></div>
          </div>
          <p>{dashboard.prestamosConMora} de {dashboard.totalPrestamosVigentes} préstamos presentan atraso.</p>
        </article>
      </div>
      <article className="panel">
        <div className="panel-heading">
          <div><p className="eyebrow">Próximos 30 días</p><h3>Vencimientos que anticipar</h3></div>
          <span className="quiet-pill">{dashboard.proximosVencimientos.length} cuotas</span>
        </div>
        <div className="due-list">
          {dashboard.proximosVencimientos.map((due) => {
            const dueDate = new Date(`${due.fechaVencimiento.slice(0, 10)}T12:00:00`);
            return (
              <div className="due-row" key={`${due.numeroPrestamo}-${due.numeroCuota}`}>
                <span className="due-date">
                  {dueDate.getDate()}
                  <small>{new Intl.DateTimeFormat("es-CR", { month: "short" }).format(dueDate)}</small>
                </span>
                <div><strong>{due.nombreCliente}</strong><small>{due.numeroPrestamo} · cuota {due.numeroCuota}</small></div>
                <span>{due.diasParaVencer} días</span>
                <strong>{currency.format(due.montoPendiente)}</strong>
              </div>
            );
          })}
        </div>
      </article>
    </section>
  );
}

function Metric({
  label,
  value,
  meta,
  tone,
}: {
  label: string;
  value: string;
  meta: string;
  tone: string;
}) {
  return (
    <article className={`metric-card ${tone}`}>
      <div className="metric-top"><span>{label}</span><span className="metric-spark">↗</span></div>
      <strong>{value}</strong>
      <small>{meta}</small>
    </article>
  );
}

function ProductForm({
  onSubmit,
  onClose,
}: {
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onClose: () => void;
}) {
  return (
    <div className="modal-backdrop">
      <form className="modal-card" onSubmit={onSubmit}>
        <div className="modal-heading">
          <div><p className="eyebrow">Catálogo</p><h3>Nuevo producto financiero</h3></div>
          <button type="button" className="close-button" onClick={onClose} aria-label="Cerrar">×</button>
        </div>
        <div className="form-grid">
          <label>Código<input name="codigoProducto" required placeholder="PRE_PYME" /></label>
          <label>Nombre<input name="nombreProducto" required placeholder="Préstamo PYME" /></label>
          <label>Tipo<select name="tipoProducto"><option>PRESTAMO</option><option>AHORRO</option><option>CERTIFICADO</option><option>OTRO</option></select></label>
          <label>Tasa anual (%)<input name="tasaInteres" type="number" min="0" max="100" step="0.01" required /></label>
          <label>Monto mínimo<input name="montoMinimoApertura" type="number" min="0" step="0.01" required /></label>
          <label>Cédula empleado<input name="cedulaEmpleado" required placeholder="EM-0103" /></label>
        </div>
        <div className="modal-actions"><button className="secondary-button" type="button" onClick={onClose}>Cancelar</button><button className="primary-button" type="submit">Guardar producto</button></div>
      </form>
    </div>
  );
}

function ManagementForm({
  alert,
  onSubmit,
  onClose,
}: {
  alert: Alert;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onClose: () => void;
}) {
  return (
    <div className="modal-backdrop">
      <form className="modal-card" onSubmit={onSubmit}>
        <div className="modal-heading">
          <div><p className="eyebrow">{alert.numeroPrestamo}</p><h3>Registrar gestión con {alert.nombreCliente}</h3></div>
          <button type="button" className="close-button" onClick={onClose} aria-label="Cerrar">×</button>
        </div>
        <div className="form-grid">
          <label>Tipo de gestión<select name="tipoGestion"><option>LLAMADA</option><option>CORREO</option><option>SMS</option><option>VISITA</option><option>ACUERDO</option></select></label>
          <label>Resultado<select name="resultado"><option>CONTACTADO</option><option>SIN_RESPUESTA</option><option>COMPROMISO_PAGO</option><option>REPROGRAMAR</option><option>PAGADO</option></select></label>
          <label>Cédula empleado<input name="cedulaEmpleado" required placeholder="EM-0102" /></label>
          <label>Fecha compromiso<input name="fechaCompromiso" type="date" /></label>
          <label>Monto compromiso<input name="montoCompromiso" type="number" min="0.01" step="0.01" /></label>
          <label className="full-field">Comentario<textarea name="comentario" required minLength={5} placeholder="Detalle del contacto y próximos pasos" /></label>
        </div>
        <div className="modal-actions"><button className="secondary-button" type="button" onClick={onClose}>Cancelar</button><button className="primary-button" type="submit">Registrar gestión</button></div>
      </form>
    </div>
  );
}

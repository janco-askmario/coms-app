const zar = new Intl.NumberFormat('en-ZA', { style: 'currency', currency: 'ZAR' });

export const money = (n: number | string | null | undefined) => zar.format(Number(n ?? 0));

export const date = (d: string | null | undefined) =>
	d ? new Date(d + 'T00:00:00').toLocaleDateString('en-ZA', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

export const STATUSES = [
	{ value: 'lead', label: 'Lead' },
	{ value: 'active', label: 'Active' },
	{ value: 'on_hold', label: 'On hold' },
	{ value: 'completed', label: 'Completed' },
	{ value: 'paid', label: 'Paid' },
	{ value: 'cancelled', label: 'Cancelled' }
] as const;

export const statusLabel = (s: string) => STATUSES.find((x) => x.value === s)?.label ?? s;

export const personName = (p: { full_name: string | null; email: string }) => p.full_name || p.email;

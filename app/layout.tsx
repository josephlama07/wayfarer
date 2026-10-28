import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Wayfarer — Plan the days worth remembering', description: 'A local-first travel journal for shaping trips, days, and ideas.' }

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>
}

"use client";

import { FormEvent, useState } from "react";

export function SupportForm() {
  const [state, setState] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [ticketID, setTicketID] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setState("sending");
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    try {
      const response = await fetch("/v1/support-requests", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ contactEmail: form.get("email"), message: form.get("message") }) });
      if (!response.ok) throw new Error("Support request failed");
      const result = await response.json() as { ticketId: string };
      setTicketID(result.ticketId); setState("sent"); formElement.reset();
    } catch { setState("error"); }
  }

  return <form className="support-form" onSubmit={submit}>
    <label>Email<input required name="email" type="email" autoComplete="email" maxLength={254} /></label>
    <label>How can we help?<textarea required name="message" minLength={10} maxLength={2000} rows={7} /></label>
    <button className="button-primary" disabled={state === "sending"}>{state === "sending" ? "Sending…" : "Send support request"}</button>
    <p role="status" aria-live="polite">{state === "sent" ? `Request received. Save ticket ${ticketID}.` : state === "error" ? "We couldn’t send that request. Please try again." : ""}</p>
  </form>;
}

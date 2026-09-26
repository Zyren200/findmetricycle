import React, { createContext, useContext, useState, useCallback } from 'react';
import Toaster from '../components/Toaster';

const ToastContext = createContext(null);

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);

  const addToast = useCallback((message, { type = 'info', duration = 4000 } = {}) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2,8)}`;
    const t = { id, message, type };
    setToasts((s) => [...s, t]);
    if (duration > 0) {
      setTimeout(() => setToasts((s) => s.filter((x) => x.id !== id)), duration);
    }
    return id;
  }, []);

  const removeToast = useCallback((id) => setToasts((s) => s.filter((x) => x.id !== id)), []);

  return (
    <ToastContext.Provider value={{ addToast, removeToast }}>
      {children}
      <Toaster toasts={toasts} onRemove={removeToast} />
    </ToastContext.Provider>
  );
}

export function useToasts() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToasts must be used within ToastProvider');
  return ctx;
}

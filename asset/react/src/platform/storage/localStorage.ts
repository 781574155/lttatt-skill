export default {
  get: (key: string) => {
    return localStorage.getItem(key);
  },
  set: (key: string, value: string) => {
    localStorage.setItem(key, value);
  },
  getJSON: (key: string): unknown => {
    const value = localStorage.getItem(key);
    if (value === null) {
      return null;
    }
    return JSON.parse(value);
  },
  setJSON: (key: string, value: unknown) => {
    localStorage.setItem(key, JSON.stringify(value));
  },
  remove: (key: string) => {
    localStorage.removeItem(key);
  },
};

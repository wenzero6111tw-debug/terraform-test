import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: 5,
  duration: '30s',
};

export default function () {
  http.get(__ENV.TARGET || 'http://localhost:4566/health');
  sleep(0.5);
}

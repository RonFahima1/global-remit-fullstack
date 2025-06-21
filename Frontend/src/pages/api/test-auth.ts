import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  console.log('TEST AUTH API ROUTE CALLED', req.method, req.body);
  res.status(200).json({ message: 'Test route works', method: req.method, body: req.body });
} 
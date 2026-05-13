import { z } from 'zod';

// schema da OpenAI
export const ScanImageResponseSchema = z.object({
  addresses: z.array(z.string()),
});
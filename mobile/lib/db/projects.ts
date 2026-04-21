import { asc, eq } from "drizzle-orm";
import { db } from "./client";
import { projects } from "./schema";
import { deleteProjectSync } from "../config/project-sync";

export const listProjects = async (): Promise<string[]> => {
  const rows = await db.select().from(projects).orderBy(asc(projects.name));
  return rows.map((r) => r.name);
};

export const addProject = async (name: string): Promise<void> => {
  const trimmed = name.trim();
  if (!trimmed) return;
  await db
    .insert(projects)
    .values({ name: trimmed, syncEnabled: false })
    .onConflictDoNothing();
};

export const removeProject = async (name: string): Promise<void> => {
  await db.delete(projects).where(eq(projects.name, name));
  await deleteProjectSync(name);
};
